#!/usr/bin/env node
const fs = require('node:fs')
const pathTools = require('node:path')
const locations = new WeakMap()
const modules = new WeakMap()

function locate(node, token) {
  if (Array.isArray(node) && !locations.has(node)) locations.set(node, [token.line, token.col])
  return node
}

const words = {skill:'SKILL',program:'PROGRAM',use:'USE',Box:'BOX',out:'OUT',enum:'ENUM',drum:'DRUM',rescue:'RESCUE',yes:'YES',no:'NO',none:'NONE'}
const signs = {'@':'AT','{':'LBRACE','}':'RBRACE','[':'LBRACKET',']':'RBRACKET','(':'LPAREN',')':'RPAREN',',':'COMMA','.':'DOT','|':'PIPE','=':'ASSIGN','>':'GT','<':'LT','+':'PLUS','-':'MINUS','*':'STAR','/':'SLASH'}
const levels = {EQ:1,GT:1,LT:1,PLUS:2,MINUS:2,STAR:3,SLASH:3}

function lex(source, path='<string>') {
  const list=[]; let i=0,line=1,col=1
  const add=(kind,value,l=line,c=col)=>list.push({kind,value,line:l,col:c})
  const fail=(message,l=line,c=col)=>{throw Error(`${path}:${l}:${c}: ${message}`)}
  while(i<source.length) {
    const ch=source[i]
    if(ch===' '||ch==='\t'||ch==='\r'){i++;col++;continue}
    if(ch==='\n'){add('NEWLINE','\n');i++;line++;col=1;continue}
    if(/\p{L}/u.test(ch)){
      const start=i,c=col
      while(i<source.length&&/[\p{L}\p{N}_]/u.test(source[i])){i++;col++}
      const value=source.slice(start,i);add(words[value]||'IDENT',value,line,c);continue
    }
    if(/\d/.test(ch)){
      const start=i,c=col;let dot=false
      while(i<source.length){
        if(/\d/.test(source[i])){i++;col++;continue}
        if(!dot&&source[i]==='.'&&/\d/.test(source[i+1]||'')){dot=true;i++;col++;continue}
        break
      }
      add('NUMBER',source.slice(start,i),line,c);continue
    }
    if(ch==='"'){
      const l=line,c=col;let value='',closed=false;i++;col++
      while(i<source.length){
        const x=source[i]
        if(x==='"'){i++;col++;closed=true;break}
        if(x==='\\'){
          if(i+1>=source.length)fail('незавершённая escape-последовательность')
          const e=source[i+1];value+=({n:'\n',t:'\t','"':'"','\\':'\\'})[e]??e;i+=2;col+=2;continue
        }
        value+=x;i++;if(x==='\n'){line++;col=1}else col++
      }
      if(!closed)fail('незавершённая строка',l,c);add('STRING',value,l,c);continue
    }
    const pair=source.slice(i,i+2)
    if(pair==='=='||pair==='=>'){add(pair==='=='?'EQ':'ARROW',pair);i+=2;col+=2;continue}
    if(!signs[ch])fail(`неожиданный символ ${JSON.stringify(ch)}`)
    add(signs[ch],ch);i++;col++
  }
  add('EOF',null);return list
}

class Parser {
  constructor(tokens,path='<string>'){this.tokens=tokens;this.path=path;this.at=0}
  peek(n=0){return this.tokens[this.at+n]}
  is(kind,n=0){return this.peek(n).kind===kind}
  take(){return this.tokens[this.at++]}
  error(message,t=this.peek()){throw Error(`разбор: ${t.line}:${t.col}: ${message}, получен ${t.kind}`)}
  expect(kind,message=`ожидался ${kind}`){if(!this.is(kind))this.error(message);return this.take()}
  ident(message='ожидался идентификатор'){return this.expect('IDENT',message).value}
  lines(){while(this.is('NEWLINE'))this.take()}
  parse(){const items=[];this.lines();while(!this.is('EOF')){items.push(this.top());this.lines()}return ['program',...items]}
  top(){
    if(this.is('USE'))return this.use()
    if(this.is('PROGRAM'))return this.entry()
    if(this.is('SKILL'))return this.skill()
    if(this.is('IDENT')&&this.is('ASSIGN',1)&&this.is('BOX',2))return this.box()
    if(this.is('IDENT')&&this.is('ASSIGN',1)&&this.is('ENUM',2))return this.enum()
    if(this.is('IDENT'))return this.constant()
    this.error('ожидалось объявление верхнего уровня')
  }
  use(){this.take();return ['use',...this.pathExpr().slice(1)]}
  entry(){this.take();this.expect('LPAREN','ожидалась ( после program');const p=this.params();this.expect('RPAREN');return ['entry',p,this.block()]}
  skill(){this.take();const n=this.ident('ожидалось имя skill');this.expect('LPAREN');const p=this.params();this.expect('RPAREN');return ['skill',n,p,this.block()]}
  params(){const p=[];if(this.is('RPAREN'))return p;while(true){p.push(this.ident('ожидалось имя параметра'));if(!this.is('COMMA'))return p;this.take()}}
  constant(){const n=this.ident();this.expect('ASSIGN');return ['const',n,this.expression()]}
  box(){const n=this.ident();this.expect('ASSIGN');this.expect('BOX');return ['box',n,...this.boxMembers()]}
  boxMembers(){
    this.expect('LBRACE');const a=[];this.lines()
    while(!this.is('RBRACE')){
      if(this.is('EOF'))this.error('ожидалась }')
      if(this.is('SKILL'))a.push(this.subjectSkill())
      else {const n=this.ident('ожидалось поле или skill');this.expect('ASSIGN','ожидался = после имени поля');a.push(['field',n,this.expression()])}
      if(this.is('COMMA'))this.take();this.lines()
    }
    this.take();return a
  }
  subjectSkill(){this.take();const n=this.ident('ожидалось имя skill');this.expect('LPAREN');const p=this.params();this.expect('RPAREN');return ['subject-skill',n,p,this.block()]}
  enum(){
    const n=this.ident();this.expect('ASSIGN');this.expect('ENUM');this.expect('LBRACE');const v=[];this.lines()
    while(!this.is('RBRACE')){v.push(this.ident('ожидался вариант enum'));if(this.is('COMMA'))this.take();this.lines()}
    this.take();return ['enum',n,...v]
  }
  block(){
    this.expect('LBRACE');const a=[];this.lines()
    while(!this.is('RBRACE')){if(this.is('EOF'))this.error('ожидалась }');a.push(this.statement());this.lines()}
    this.take();return ['block',...a]
  }
  statement(){
    if(this.is('AT'))return this.variable()
    if(this.is('OUT')){this.take();return ['out',this.expression()]}
    if(this.is('DRUM'))return this.drum()
    if(this.is('LPAREN'))return this.parenBlock()
    if(this.assignmentAhead()){
      const target=this.pathExpr();this.expect('ASSIGN')
      if(target.length===2)return ['assign',target[1],this.expression()]
      return ['field-assign',target,this.expression()]
    }
    return ['expr',this.expression()]
  }
  assignmentAhead(){let n=1;while(this.is('DOT',n)&&this.is('IDENT',n+1))n+=2;return this.is('ASSIGN',n)}
  variable(){this.take();const n=this.ident('ожидалось имя переменной');this.expect('ASSIGN','ожидался = после имени переменной');return ['var',n,this.expression()]}
  drum(){this.take();this.expect('LPAREN','ожидалась ( после drum');const n=this.expression();this.expect('RPAREN');return ['drum',n,this.block()]}
  parenBlock(){
    const start=this.take();const value=this.expression();this.expect('RPAREN');this.expect('LBRACE');this.lines()
    if(this.is('DOT'))return this.switch(value)
    const a=[];while(!this.is('RBRACE')){a.push(this.statement());this.lines()}this.take();return ['if',value,locate(['block',...a],start)]
  }
  switch(value){
    const a=[];while(!this.is('RBRACE')){const start=this.peek();this.expect('DOT');const tag=this.ident('ожидалась метка ветки выбора');this.expect('ARROW');a.push(locate(['case',tag,this.expression()],start));if(this.is('COMMA'))this.take();this.lines()}
    this.take();return ['switch',value,...a]
  }
  expression(){
    let value=this.binary(0)
    if(this.is('RESCUE')){const start=this.take();this.expect('PIPE');const err=this.ident('ожидалось имя ошибки rescue');this.expect('PIPE');value=locate(['rescue',value,err,this.block()],start)}
    return value
  }
  binary(min){
    let left=this.postfix()
    while(true){const op=this.peek(),level=levels[op.kind];if(level===undefined||level<min)return left;this.take();left=locate(['binary',op.value,left,this.binary(level+1)],op)}
  }
  postfix(){
    let value=this.primary()
    while(true){
      if(this.is('LPAREN')){const start=this.peek();value=locate(['call',value,...this.args()],start);continue}
      if(value[0]==='path'&&this.is('LBRACE')){const start=this.peek();value=locate(['box-new',value.slice(1).join('.'),...this.fields()],start);continue}
      return value
    }
  }
  fields(){
    this.expect('LBRACE');const a=[];this.lines()
    while(!this.is('RBRACE')){if(this.is('EOF'))this.error('ожидалась }');const n=this.ident('ожидалось имя поля');this.expect('ASSIGN','ожидался = после имени поля');a.push(['field',n,this.expression()]);if(this.is('COMMA'))this.take();this.lines()}
    this.take();return a
  }
  args(){
    this.take();const a=[];if(this.is('RPAREN')){this.take();return a}
    while(true){a.push(this.expression());if(!this.is('COMMA'))break;this.take()}this.expect('RPAREN');return a
  }
  primary(){
    if(this.is('NUMBER')){
      const text=this.take().value
      if(!text.includes('.')&&Number(text)>268435455)return ['wide-number',text]
      return ['number',Number(text)]
    }
    if(this.is('STRING'))return ['string',this.take().value]
    if(this.is('YES')){this.take();return ['answer','yes']}
    if(this.is('NO')){this.take();return ['answer','no']}
    if(this.is('NONE')){this.take();return ['none']}
    if(this.is('DOT')){this.take();return ['enum-value',this.ident('ожидалось значение enum')]}
    if(this.is('LBRACKET'))return this.group()
    if(this.is('IDENT'))return this.pathExpr()
    if(this.is('LPAREN')){this.take();const v=this.expression();this.expect('RPAREN');return v}
    this.error('ожидалось выражение')
  }
  group(){
    this.take();const a=[];this.lines();while(!this.is('RBRACKET')){if(this.is('EOF'))this.error('ожидалась ]');a.push(this.expression());if(this.is('COMMA'))this.take();this.lines()}this.take();return ['group',...a]
  }
  pathExpr(){const a=[this.ident()];while(this.is('DOT')&&this.is('IDENT',1)){this.take();a.push(this.ident())}return ['path',...a]}
}

for (const name of ['use','entry','skill','subjectSkill','constant','box','enum','block','variable','drum','parenBlock','group','pathExpr','primary']) {
  const parse = Parser.prototype[name]
  Parser.prototype[name] = function (...args) {
    const start = this.peek()
    return locate(parse.apply(this, args), start)
  }
}

const originalStatement = Parser.prototype.statement
Parser.prototype.statement = function (...args) {
  const start = this.peek()
  const node = originalStatement.apply(this, args)
  if (node[0] === 'assign' || node[0] === 'field-assign' || node[0] === 'out') locate(node, start)
  return node
}

function astWithLocations(value) {
  if (!Array.isArray(value)) return value
  const node = value.map(astWithLocations)
  if (modules.has(value)) modules.set(node, modules.get(value))
  const point = locations.get(value)
  return point ? ['loc', point[0], point[1], node] : node
}

function moduleOf(node) {
  const plain = stripLocation(node)
  return modules.get(plain) ?? null
}

function stripLocation(value) {
  return Array.isArray(value) && value[0] === 'loc' ? value[3] : value
}

const coreFiles = ['file.saltic','json.saltic','str.saltic','num.saltic','group.saltic']

function modulePath(sourcePath, parts, root) {
  const relative = pathTools.join(...parts.slice(0,-1), `${parts.at(-1)}.saltic`)
  const result = pathTools.resolve(['s','s2'].includes(parts[0]) ? root : pathTools.dirname(sourcePath), relative)
  if (!fs.existsSync(result)) throw Error(`модули: модуль '${parts.join('.')}' не найден: ${result}`)
  return result
}

function loadFile(path, options={}) {
  const root = options.root ?? pathTools.resolve(__dirname, '..')
  const withLocations = options.locations ?? false
  const expandCore = options.expandCore ?? true
  const included = new Set()
  function expand(file, stack=[], module=[]) {
    const normalized = pathTools.resolve(file)
    if (stack.includes(normalized)) throw Error(`модули: циклический импорт: ${normalized}`)
    if (included.has(normalized)) return []
    included.add(normalized)
    const ast = parseFile(normalized)
    const datum = withLocations ? astWithLocations(ast) : ast
    const program = stripLocation(datum)
    const output=[]
    for (const item of program.slice(1)) {
      const plain=stripLocation(item)
      if (plain[0] === 'entry' && stack.length) continue
      modules.set(stripLocation(item), module)
      output.push(item)
      if (plain[0] !== 'use') continue
      if (plain.length === 2 && plain[1] === 'core') {
        if (expandCore) for (const name of coreFiles) output.push(...expand(pathTools.join(root,'core',name),[normalized,...stack],['core',name.slice(0,-7)]))
      } else {
        const imported = plain.slice(1)
        output.push(...expand(modulePath(normalized,imported,root),[normalized,...stack],imported))
      }
    }
    return output
  }
  return ['program',...expand(path)]
}

function parseString(source,path='<string>'){return new Parser(lex(source,path),path).parse()}
function parseFile(path){return parseString(fs.readFileSync(path,'utf8'),path)}
module.exports={lex,parseString,parseFile,astWithLocations,moduleOf,loadFile}

if(require.main===module){
  if(process.argv.length!==3){console.error('использование: node js/1-parser.js <файл.saltic>');process.exit(2)}
  try{console.log(JSON.stringify(parseFile(process.argv[2]),null,2))}catch(error){console.error(error.message);process.exit(1)}
}
