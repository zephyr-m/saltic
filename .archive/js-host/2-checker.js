#!/usr/bin/env node
const parser=require('./1-parser')
const strip=n=>{const plain=Array.isArray(n)&&n[0]==='loc'?n[3]:n;return Array.isArray(plain)&&plain[0]==='wide-number'?['number',Number(plain[1])]:plain}
const place=n=>Array.isArray(n)&&n[0]==='loc'?[n[1],n[2]]:null
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b)
const typeText=t=>Array.isArray(t)?(t[0]==='box'?`Box ${t[1]}`:t[0]==='enum'?`enum ${t[1]}`:`группа ${typeText(t[1])}`):t==='answer'?'yes/no':t
const merge=(a,b)=>a==='unknown'?b:b==='unknown'?a:same(a,b)?a:Array.isArray(a)&&Array.isArray(b)&&a[0]==='group'&&b[0]==='group'?['group',merge(a[1],b[1])]:'unknown'
const compatible=(a,b)=>a==='unknown'||b==='unknown'||same(a,b)||(Array.isArray(a)&&Array.isArray(b)&&a[0]==='group'&&b[0]==='group'&&compatible(a[1],b[1]))
function code(m){if(/^значение .+ не помещается в /.test(m))return'fixed_integer_out_of_range';if(/^core\.(mem|bits32)\./.test(m))return'type_mismatch';if(/^операция |^оператор |^для арифметики адресов/.test(m))return'operator_type_mismatch';if(/^модуль 'core' не импортирован/.test(m))return'core_not_imported';if(/^неподдерживаемый модуль/.test(m))return'unsupported_module';if(/^неизвестное имя/.test(m))return'unknown_name';if(/^переменная '.+' не объявлена/.test(m))return'variable_not_declared';if(/^нельзя присвоить значение константе/.test(m))return'constant_assignment';if(/^нельзя присвоить .+ переменной/.test(m))return'type_mismatch';if(/^повторн/.test(m))return'duplicate_definition';if(/^'out' можно использовать только/.test(m))return'out_outside_skill';return'checker_error'}
function diagnostic(loc,message){const d={level:'error',code:code(message),message};if(loc){d.line=loc[0];d.col=loc[1]}if(d.code==='core_not_imported')d.hint='добавь `use core` на верхнем уровне';if(d.code==='variable_not_declared')d.hint='объяви переменную через `@name = value` перед присваиванием';if(d.code==='constant_assignment')d.hint='константы неизменяемы; для изменяемого значения используй локальную переменную';return d}
class Scope{constructor(parent=null){this.vars=new Map;this.parent=parent;this.subject=parent?.subject??null;this.module=parent?.module??[]}find(n){return this.vars.has(n)?this:this.parent?.find(n)}get(n){return this.find(n)?.vars.get(n)}set(n,t){const s=this.find(n);if(s)s.vars.set(n,t);return s}}
const result=(type,diagnostics=[])=>({type,diagnostics})
function literal(n){n=strip(n);if(n[0]==='number')return'number';if(n[0]==='string')return'string';if(n[0]==='answer')return'answer';if(n[0]==='none')return'none';if(n[0]==='box-new')return['box',n[1]];if(n[0]==='group')return['group',n.slice(1).reduce((t,x)=>merge(t,literal(x)),'unknown')];return'unknown'}
const qualified=(module,name)=>[...module,name].join('.')
function candidates(parts,env,g){const direct=parts.join('.'),list=[direct],local=qualified(env.module,direct);if(local!==direct)list.push(local);const alias=g.aliases.get(env.module.join('.'))?.get(parts[0]);if(alias)list.push([alias,...parts.slice(1)].join('.'));return list}
const resolved=(map,parts,env,g)=>candidates(parts,env,g).find(name=>map.has(name))??null
function globals(items){
  const g={constants:new Map,enums:new Map,boxes:new Map,subjectSkills:new Map,skills:new Map,imports:new Set,aliases:new Map,entry:null},ds=[]
  const exists=n=>g.constants.has(n)||g.enums.has(n)||g.boxes.has(n)||g.skills.has(n)
  const put=(map,n,v)=>exists(n)?ds.push(diagnostic(null,`повторное имя верхнего уровня '${n}'`)):map.set(n,v)
  for(const raw of items){
    const n=strip(raw),module=parser.moduleOf(raw)??[],moduleKey=module.join('.'),name=n[1]?qualified(module,n[1]):''
    if(n[0]==='use'){
      const imported=n.slice(1),alias=imported.at(-1),target=imported.join('.'),aliases=g.aliases.get(moduleKey)??new Map
      if(aliases.has(alias)&&aliases.get(alias)!==target)ds.push(diagnostic(null,`повторный псевдоним модуля '${alias}'`));else aliases.set(alias,target)
      g.aliases.set(moduleKey,aliases);g.imports.add(JSON.stringify(imported))
    }else if(n[0]==='const')put(g.constants,name,literal(n[2]))
    else if(n[0]==='box'){put(g.boxes,name,n.slice(2).filter(x=>strip(x)[0]==='field'));g.subjectSkills.set(name,new Map(n.slice(2).filter(x=>strip(x)[0]==='subject-skill').map(x=>{const s=strip(x);return[s[1],s]})))}
    else if(n[0]==='enum')put(g.enums,name,n.slice(2))
    else if(n[0]==='skill')put(g.skills,name,n[2])
    else if(n[0]==='entry'&&!module.length){if(g.entry)ds.push(diagnostic(null,'повторное объявление program'));else g.entry=[n[1],n[2]]}
  }
  return[g,ds]
}
const core=g=>g.imports.has(JSON.stringify(['core']))
const top=(g,n)=>g.constants.has(n)||g.enums.has(n)||g.boxes.has(n)||g.skills.has(n)
function fieldLiteral(raw,box,g){const type=literal(raw);if(Array.isArray(type)&&type[0]==='box'&&!g.boxes.has(type[1])){const module=box.split('.').slice(0,-1),local=qualified(module,type[1]);if(g.boxes.has(local))return['box',local]}return type}
function fieldType(box,name,g){const f=g.boxes.get(box)?.find(x=>strip(x)[1]===name);return f?fieldLiteral(strip(f)[2],box,g):null}
function fieldPath(type,fields,g,loc){for(const f of fields){if(type==='unknown')return result('unknown');if(Array.isArray(type)&&type[0]==='box'){const next=fieldType(type[1],f,g);if(!next)return result('unknown',[diagnostic(loc,`в Box '${type[1]}' нет поля '${f}'`)]);type=next}else return result('unknown',[diagnostic(loc,`нельзя обратиться к полю '${f}' у ${typeText(type)}`)])}return result(type)}
function pathType(parts,env,g,loc){
  if(parts.length===1&&env.get(parts[0]))return result(env.get(parts[0]))
  const constant=resolved(g.constants,parts,env,g);if(constant)return result(g.constants.get(constant))
  if(resolved(g.skills,parts,env,g))return result('function')
  if(resolved(g.boxes,parts,env,g))return result('box-type')
  if(resolved(g.enums,parts,env,g))return result('enum-type')
  if(parts.length>1){const enumName=resolved(g.enums,parts.slice(0,-1),env,g);if(enumName)return g.enums.get(enumName).includes(parts.at(-1))?result(['enum',enumName]):result('unknown',[diagnostic(loc,`в enum '${enumName}' нет варианта '${parts.at(-1)}'`)])}
  const [head,...tail]=parts
  if(['host','world','visual','ui'].includes(head))return result('module-path')
  if(head==='core')return core(g)?result('module-path'):result('unknown',[diagnostic(loc,"модуль 'core' не импортирован; добавь 'use core'")])
  if(head==='error')return result('error')
  const t=env.get(head);return t?fieldPath(t,tail,g,loc):parts.length===1?result('unknown',[diagnostic(loc,`неизвестное имя '${head}'`)]):result('unknown')
}
const calls={
'host.io.show':'none','host.file.read':'string','host.file.write':'none','host.json.encode':'string','host.str.line_count':'number','host.str.lines':['group','string'],'host.str.len':'number','host.str.at':'string','host.str.slice':'string','host.str.join':'string','host.str.eq':'answer','host.str.contains':'answer','host.str.trim':'string','host.str.upper':'string','host.str.lower':'string','host.str.split':['group','string'],'host.math.parse':'number','host.math.abs':'number','host.math.min':'number','host.math.max':'number','host.math.round':'number','host.debug.show':'none',
'core.io.show':'none','core.file.read':'string','core.file.write':'none','core.json.encode':'string','core.str.line_count':'number','core.str.lines':['group','string'],'core.str.len':'number','core.str.at':'string','core.str.byte':'number','core.str.slice':'string','core.str.join':'string','core.str.add':'string','core.str.eq':'answer','core.str.is_empty':'answer','core.str.starts_with':'answer','core.str.ends_with':'answer','core.str.contains':'answer','core.str.trim':'string','core.str.upper':'string','core.str.lower':'string','core.str.split':['group','string'],'core.num.parse':'number','core.num.abs':'number','core.num.min':'number','core.num.max':'number','core.num.round':'number','core.group.count':'number','core.mem.load8':'number','core.mem.load16':'number','core.mem.load32':'number','core.mem.store8':'none','core.mem.store16':'none','core.mem.store32':'none','core.mem.store_address32':'none','core.cpu.wait':'none','core.cpu.fence':'none',
'world.spawn':'unknown','world.place':'none','world.move':'none','world.emit':'none','world.step':'none','world.trace':'none','world.trace_text':'string','world.state':'none','world.state_text':'string','world.replay':'string','visual.sheet':'none','visual.grid':'none','visual.square_bipyramid':'none','visual.rotate':'none','visual.present':'none','visual.trace':'none','visual.trace_text':'string','ui.panel':'none','ui.text':'none','ui.field':'none','ui.button':'none','ui.value':'none','ui.present':'none','ui.trace':'none','ui.trace_text':'string'}
const fixedTypes=new Set(['u8','u16','u32','i32','bits32','address','usize'])
const integerTypes=new Set(['u8','u16','u32','i32','usize'])
const ranges={u8:[0,255],u16:[0,65535],u32:[0,4294967295],i32:[-2147483648,2147483647],bits32:[0,4294967295],usize:[0,4294967295]}
function constantInteger(raw){const n=strip(raw);if(n?.[0]==='number')return n[1];if(n?.[0]==='wide-number')return Number(n[1]);if(n?.[0]==='binary'&&n[1]==='-'){const l=constantInteger(n[2]),r=constantInteger(n[3]);if(l!==null&&r!==null)return l-r}return null}
function fixedCall(key,rawArgs,args,loc){
  const ds=[]
  if(fixedTypes.has(key)){
    const value=constantInteger(rawArgs[0])
    if(key==='address')return result('address',args.flatMap(x=>x.diagnostics))
    if(value!==null&&ranges[key]&&(value<ranges[key][0]||value>ranges[key][1]))ds.push(diagnostic(loc,`значение ${value} не помещается в ${key}: допустимо ${ranges[key][0]}..${ranges[key][1]}`))
    return result(key,[...args.flatMap(x=>x.diagnostics),...ds])
  }
  const conversion=/^core\.(u8|u16|u32|i32|usize)\.from$/.exec(key)
  if(conversion)return result(conversion[1],args.flatMap(x=>x.diagnostics))
  const bits=/^core\.bits32\.(and|or|xor|not|shift_left|shift_right)$/.exec(key)
  if(bits){
    const expected=bits[1].startsWith('shift_')?['bits32','u8']:bits[1]==='not'?['bits32']:['bits32','bits32']
    args.forEach((arg,index)=>{if(expected[index]&&arg.type!=='unknown'&&arg.type!==expected[index])ds.push(diagnostic(loc,`core.bits32.${bits[1]} ожидает ${index===1&&bits[1].startsWith('shift_')?'сдвиг ':''}${expected[index]}, получено ${typeText(arg.type)}`))})
    return result('bits32',[...args.flatMap(x=>x.diagnostics),...ds])
  }
  if(key==='core.address.add')return result('address',args.flatMap(x=>x.diagnostics))
  const memory=/^core\.mem\.(load|store)(8|16|32)$/.exec(key)
  if(memory&&args[0]?.type==='address'){
    const valueType=`u${memory[2]}`
    if(memory[1]==='store'&&args[2]?.type!=='unknown'&&args[2]?.type!==valueType)ds.push(diagnostic(loc,`${key} ожидает значение ${valueType}, получено ${typeText(args[2].type)}`))
    return result(memory[1]==='load'?valueType:'none',[...args.flatMap(x=>x.diagnostics),...ds])
  }
  return null
}
function callType(callee,args,env,g){const n=strip(callee);if(n[0]!=='path')return'unknown';const parts=n.slice(1),key=parts.join('.'),box=resolved(g.boxes,parts,env,g);if(box)return['box',box];if(key==='core.group.at')return Array.isArray(args[0]?.type)&&args[0].type[0]==='group'?args[0].type[1]:'unknown';if(key==='core.group.append')return['group',merge(Array.isArray(args[0]?.type)?args[0].type[1]:'unknown',args[1]?.type??'unknown')];return calls[key]??'unknown'}
function callExpression(callee,rawArgs,env,g,loc){const n=strip(callee),args=rawArgs.map(x=>expression(x,env,g)),argDiagnostics=args.flatMap(x=>x.diagnostics);if(n[0]==='path'){const special=fixedCall(n.slice(1).join('.'),rawArgs,args,loc);if(special)return special}if(n[0]==='path'&&n.length===2&&env.subject&&g.subjectSkills.get(env.subject)?.has(n[1]))return result('unknown',argDiagnostics);if(n[0]==='path'&&n.length===3){const receiver=pathType([n[1]],env,g,loc);if(Array.isArray(receiver.type)&&receiver.type[0]==='box'&&g.subjectSkills.get(receiver.type[1])?.has(n[2]))return result('unknown',[...receiver.diagnostics,...argDiagnostics])}const c=expression(callee,env,g);return result(callType(callee,args,env,g),[...c.diagnostics,...argDiagnostics])}
function expression(raw,env,g){const loc=place(raw),n=strip(raw),tag=n[0];if(tag==='number')return result('number');if(tag==='string')return result('string');if(tag==='answer')return result('answer');if(tag==='none')return result('none');if(tag==='enum-value')return result('enum-value');if(tag==='path')return pathType(n.slice(1),env,g,loc);if(tag==='group'){const rs=n.slice(1).map(x=>expression(x,env,g));return result(['group',rs.reduce((t,x)=>merge(t,x.type),'unknown')],rs.flatMap(x=>x.diagnostics))}if(tag==='box-new')return boxNew(n[1],n.slice(2),env,g,loc);if(tag==='call')return callExpression(n[1],n.slice(2),env,g,loc);if(tag==='binary'){const l=expression(n[2],env,g),r=expression(n[3],env,g),ds=[...l.diagnostics,...r.diagnostics],op=n[1];if(['+','-','*','/','>','<'].includes(op)&&l.type!=='unknown'&&r.type!=='unknown'){
  if(l.type==='address'||r.type==='address')ds.push(diagnostic(loc,'для арифметики адресов используй core.address.add(address, usize)'))
  else if(l.type==='bits32'||r.type==='bits32')ds.push(diagnostic(loc,`операция '${op}' недоступна для bits32: используй операции core.bits32`))
  else if(fixedTypes.has(l.type)||fixedTypes.has(r.type)){
    if(l.type!==r.type)ds.push(diagnostic(loc,integerTypes.has(l.type)&&integerTypes.has(r.type)?`операция '${op}' требует одинаковые фиксированные целые типы: получены ${typeText(l.type)} и ${typeText(r.type)}`:`операция '${op}' не может смешивать ${typeText(l.type)} и ${typeText(r.type)}`))
  } else if(l.type!=='number'||r.type!=='number')ds.push(diagnostic(null,`оператор '${op}' ожидает числа, получено ${typeText(l.type)} и ${typeText(r.type)}`))
  return result(['==','>','<'].includes(op)?'answer':l.type,ds)
}return result(['==','>','<'].includes(op)?'answer':['+','-','*','/'].includes(op)?'number':'unknown',ds)}if(tag==='rescue'){const a=expression(n[1],env,g),child=new Scope(env);child.vars.set(n[2],'error');const b=blockValue(n[3],child,g);return result(merge(a.type,b.type),[...a.diagnostics,...b.diagnostics])}return result('unknown',[diagnostic(loc,`неподдерживаемое выражение ${JSON.stringify(n)}`)])}
function boxNew(name,fields,env,g,loc){const box=resolved(g.boxes,name.split('.'),env,g);if(!box)return result('unknown',[diagnostic(loc,`неизвестный Box '${name}'`)]);const model=g.boxes.get(box),expected=new Map(model.map(f=>[strip(f)[1],fieldLiteral(strip(f)[2],box,g)])),seen=new Set,ds=[];for(const f0 of fields){const f=strip(f0),key=f[1],r=expression(f[2],env,g);ds.unshift(...r.diagnostics);if(seen.has(key))ds.unshift(diagnostic(loc,`повторное поле '${key}' в литерале Box '${name}'`));seen.add(key);if(!expected.has(key))ds.unshift(diagnostic(loc,`в Box '${name}' нет поля '${key}'`));else if(!compatible(expected.get(key),r.type))ds.unshift(diagnostic(loc,`нельзя присвоить ${typeText(r.type)} полю '${key}' Box '${name}' типа ${typeText(expected.get(key))}`))}return result(['box',box],ds.reverse())}
function blockValue(b,env,g){const ds=block(b,env,g,true),a=strip(b).slice(1),last=a.length?strip(a.at(-1)):null,t=last&&['expr','out'].includes(last[0])?expression(last[1],env,g).type:'none';return result(t,ds)}
function block(raw,env,g,inSkill){const n=strip(raw);if(n[0]!=='block')return[diagnostic(null,'ожидался AST блока')];return n.slice(1).flatMap(s=>statement(s,env,g,inSkill))}
function statement(raw,env,g,inSkill){const loc=place(raw),n=strip(raw),tag=n[0];if(tag==='var'){const r=expression(n[2],env,g),ds=[...r.diagnostics];if(env.vars.has(n[1]))ds.push(diagnostic(loc,`переменная '${n[1]}' уже объявлена в этой области`));else if(top(g,n[1]))ds.push(diagnostic(loc,`переменная '${n[1]}' конфликтует с именем верхнего уровня`));else env.vars.set(n[1],r.type);return ds}if(tag==='assign'){const r=expression(n[2],env,g),ds=[...r.diagnostics],name=n[1];if(g.constants.has(name))ds.push(diagnostic(loc,`нельзя присвоить значение константе '${name}'`));else if(top(g,name))ds.push(diagnostic(loc,`нельзя присвоить значение имени верхнего уровня '${name}'`));else{const old=env.get(name);if(!old)ds.push(diagnostic(loc,`переменная '${name}' не объявлена`));else if(compatible(old,r.type))env.set(name,merge(old,r.type));else ds.push(diagnostic(loc,`нельзя присвоить ${typeText(r.type)} переменной '${name}' типа ${typeText(old)}`))}return ds}if(tag==='field-assign'){const parts=strip(n[1]).slice(1),base=pathType(parts.slice(0,-1),env,g,loc),value=expression(n[2],env,g),ds=[...base.diagnostics,...value.diagnostics];if(Array.isArray(base.type)&&base.type[0]==='box'){const expected=fieldType(base.type[1],parts.at(-1),g);if(!expected)ds.push(diagnostic(loc,`в Box '${base.type[1]}' нет поля '${parts.at(-1)}'`));else if(!compatible(expected,value.type))ds.push(diagnostic(loc,`нельзя присвоить ${typeText(value.type)} полю '${parts.at(-1)}' Box '${base.type[1]}'`))}return ds}if(tag==='out')return[...(!inSkill?[diagnostic(loc,"'out' можно использовать только внутри skill")]:[]),...expression(n[1],env,g).diagnostics];if(tag==='expr')return expression(n[1],env,g).diagnostics;if(tag==='if')return[...expression(n[1],env,g).diagnostics,...block(n[2],new Scope(env),g,inSkill)];if(tag==='switch')return[...expression(n[1],env,g).diagnostics,...n.slice(2).flatMap(c=>expression(strip(c)[2],env,g).diagnostics)];if(tag==='drum')return[...expression(n[1],env,g).diagnostics,...block(n[2],new Scope(env),g,inSkill)];return[diagnostic(loc,`неподдерживаемая инструкция ${JSON.stringify(n)}`)]}
function checkDatum(ast){const n=strip(ast);if(n[0]!=='program')return[diagnostic(null,'ожидался AST программы')];const [g,start]=globals(n.slice(1)),ds=[...start];for(const raw of n.slice(1)){const x=strip(raw),module=parser.moduleOf(raw)??[],scope=()=>{const env=new Scope;env.module=module;return env};if(x[0]==='const')ds.push(...expression(x[2],scope(),g).diagnostics);else if(x[0]==='box'){const seen=new Set,methods=new Set,fields=x.slice(2).map(strip).filter(f=>f[0]==='field');for(const f of fields){if(seen.has(f[1]))ds.push(diagnostic(null,`повторное поле '${f[1]}' в Box '${x[1]}'`));seen.add(f[1]);ds.push(...expression(f[2],scope(),g).diagnostics)}for(const method of x.slice(2).map(strip).filter(f=>f[0]==='subject-skill')){if(methods.has(method[1]))ds.push(diagnostic(null,`повторный skill '${method[1]}' в Box '${x[1]}'`));methods.add(method[1]);const env=scope();env.subject=qualified(module,x[1]);for(const f of fields)env.vars.set(f[1],fieldLiteral(f[2],qualified(module,x[1]),g));for(const p of method[2])env.vars.has(p)?ds.push(diagnostic(null,`повторный параметр '${p}'`)):env.vars.set(p,'unknown');ds.push(...block(method[3],env,g,true))}}else if(x[0]==='entry'||x[0]==='skill'){const env=scope();for(const p of x[0]==='entry'?x[1]:x[2])env.vars.has(p)?ds.push(diagnostic(null,`повторный параметр '${p}'`)):env.vars.set(p,'unknown');ds.push(...block(x[0]==='entry'?x[2]:x[3],env,g,true))}}return ds}
function checkFile(file){return checkDatum(parser.loadFile(file,{locations:true}))}
const text=d=>d.line?`${d.line}:${d.col}: ошибка: ${d.message}`:`ошибка: ${d.message}`
module.exports={checkFile,checkDatum,diagnosticsToJSON:ds=>({ok:ds.length===0,diagnostics:ds}),diagnosticText:text}
if(require.main===module){const args=process.argv.slice(2),json=args[0]==='--json',file=args[json?1:0];if(!file||args.length!==(json?2:1)){console.error('использование: node js/2-checker.js [--json] <файл.saltic>');process.exit(2)}try{const ds=checkFile(file);if(json)console.log(JSON.stringify({ok:!ds.length,diagnostics:ds}));else if(!ds.length)console.log('ок');else ds.forEach(d=>console.error(text(d)));if(ds.length)process.exit(1)}catch(e){if(json)console.log(JSON.stringify({ok:false,diagnostics:[{level:'error',code:'tool_error',message:e.message}]}));else console.error(e.message);process.exit(1)}}
