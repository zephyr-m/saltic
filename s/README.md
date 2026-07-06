# S-owned code skeleton

This directory is the future S-owned system.

Current bootstrap still lives mostly in:

```text
tools/*.rkt
examples/bootstrap/tiny_vm/core.s
std/*.s
```

tree
    s/
        make/
            language/
                syntax.s
                grammar.s
                types.s
                effects.s
                modules.s
                errors.s
            compiler/
                main.s
                lexer/
                    token.s
                    scanner.s
                syntax/
                    parser.s
                    ast.s
                    source_map.s
                semantics/
                    scope.s
                    checker.s
                    diagnostics.s
                emit/
                    emitter.s
                pipeline/
                    pipeline.s
            ir/
                node.s
                lowering.s
                validation.s
                optimize.s
                print.s
            backend/
                target.s
                bytecode.s
                native.s
                c.s
                wasm.s
                custom_cpu.s
            artifact/
                bytecode.s
                object.s
                object_format.s
                executable.s
                library.s
                firmware.s
                package.s
                debug_info.s

        run/
            bytecode/
                instruction.s
                literal.s
                program.s
                encoding.s
                validation.s
                disasm.s
            vm/
                value.s
                bytecode_data.s
                frame.s
                stack.s
                env.s
                step.s
                interpreter.s
                boundary.s
                loader.s
                trace.s
                scheduler.s
                gc.s
            runtime/
                runtime.s
                core.s
                values.s
                calls.s
                scopes.s
                modules.s
                memory.s
                process.s
                concurrency.s
                assets.s
                panic.s
                log.s
                world.s
                visual.s
                debug.s
            std/
                str.s
                num.s
                math.s
                vec.s
                matrix.s
                file.s
                json.s
                group.s
                io.s
                net.s
                time.s
                path.s
                process.s
                log.s
                test.s
                crypto.s
                random.s
            host/
                boundary.s
                effects.s
                file_system.s
                console.s
                network.s
                input.s
                audio.s
                window.s
                os.s
                time.s
                process.s
                random.s
                crypto.s
                threads.s
                graphics.s
                primitives.s
            effects/
                effects.s
                check.s
                machine_trace.s

        machine/
            target/
                target.s
                abi.s
                memory.s
                x86_64.s
                arm64.s
                riscv.s
                wasm.s
                custom_cpu.s
            platform/
                posix.s
                linux.s
                windows.s
                macos.s
                browser.s
                bare_metal.s
            boot/
                entry.s
                image.s
                memory_map.s
            kernel/
                kernel.s
                memory.s
                interrupt.s
                scheduler.s
                syscall.s
                panic.s
            device/
                bus.s
                pci.s
                usb.s
                clock.s
            driver/
                display.s
                gpu.s
                input.s
                audio.s
                storage.s
                network.s

        world/
            filesystem/
                vfs.s
                block.s
                fat.s
            network_stack/
                packet.s
                ethernet.s
                ip.s
                tcp.s
                udp.s
                dns.s
            graphics_stack/
                framebuffer.s
                gpu_command.s
                shader.s
                renderer.s
                compositor.s
                font.s
            security/
                capability.s
                permission.s
                sandbox.s

        tools/
            tooling/
                build.s
                asset_pipeline.s
                debugger.s
                formatter.s
                explainer.s
                test_runner.s
                task_runner.s
                package.s
                profiler.s
                linter.s
                repl.s
                docgen.s

pipeline
    bytecode VM
        source.s
            -> make/compiler/lexer/scanner.s
            -> make/compiler/syntax/parser.s
            -> make/compiler/syntax/ast.s
            -> make/compiler/semantics/checker.s
            -> make/ir/node.s
            -> make/ir/lowering.s
            -> make/backend/bytecode.s
            -> make/artifact/bytecode.s
            -> run/vm/loader.s
            -> run/vm/interpreter.s

    C/native host
        source.s
            -> make/compiler/lexer/scanner.s
            -> make/compiler/syntax/parser.s
            -> make/compiler/syntax/ast.s
            -> make/compiler/semantics/checker.s
            -> make/ir/node.s
            -> make/ir/lowering.s
            -> make/backend/c.s
            -> make/artifact/executable.s

    custom firmware
        source.s
            -> make/compiler/lexer/scanner.s
            -> make/compiler/syntax/parser.s
            -> make/compiler/syntax/ast.s
            -> make/compiler/semantics/checker.s
            -> make/ir/node.s
            -> make/ir/lowering.s
            -> make/backend/custom_cpu.s
            -> machine/target/custom_cpu.s
            -> machine/platform/bare_metal.s
            -> make/artifact/firmware.s

    bit to pixel
        source.s
            -> make/compiler/lexer/scanner.s
            -> make/compiler/syntax/parser.s
            -> make/compiler/syntax/ast.s
            -> make/compiler/semantics/checker.s
            -> make/ir/node.s
            -> make/ir/lowering.s
            -> make/backend/native.s
            -> machine/target/riscv.s
            -> make/artifact/executable.s
            -> machine/boot/entry.s
            -> machine/kernel/kernel.s
            -> machine/driver/display.s
            -> world/graphics_stack/framebuffer.s
            -> world/graphics_stack/renderer.s
