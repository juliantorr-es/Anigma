import os
import glob

files = [
    "anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Integration/AnigmaPlatform.swift",
    "anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Integration/SecuredWorld.swift",
    "anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/PlatformRuntime.swift",
    "anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/AuthorityImplementations.swift"
]

for file in files:
    with open(file, "r") as f:
        lines = f.readlines()
    
    with open(file, "w") as f:
        for line in lines:
            # AuditLog
            if "try? await (await governance.auditLog).recordEvent(" in line:
                indent = line[:len(line) - len(line.lstrip())]
                f.write(f"{indent}let auditLog = await governance.auditLog\n")
                f.write(line.replace("try? await (await governance.auditLog).recordEvent(", "try? await auditLog.recordEvent("))
            
            # AccessController checkAccess(request)
            elif "try await (await governance.accessController).checkAccess(request)" in line:
                indent = line[:len(line) - len(line.lstrip())]
                f.write(f"{indent}let accessController = await governance.accessController\n")
                f.write(line.replace("try await (await governance.accessController).checkAccess(request)", "try await accessController.checkAccess(request)"))

            # AccessController checkAccess(accessRequest)
            elif "try await (await governance.accessController).checkAccess(accessRequest)" in line:
                indent = line[:len(line) - len(line.lstrip())]
                f.write(f"{indent}let accessController = await governance.accessController\n")
                f.write(line.replace("try await (await governance.accessController).checkAccess(accessRequest)", "try await accessController.checkAccess(accessRequest)"))

            # security.enforcementEngine
            elif "let decision = await (await security.enforcementEngine).enforce(threat)" in line:
                indent = line[:len(line) - len(line.lstrip())]
                f.write(f"{indent}let engine = await security.enforcementEngine\n")
                f.write(line.replace("let decision = await (await security.enforcementEngine).enforce(threat)", "let decision = await engine.enforce(threat)"))
                
            # killSwitch activate (multiline)
            elif "await (await governance.killSwitch).activate(" in line:
                indent = line[:len(line) - len(line.lstrip())]
                f.write(f"{indent}let killSwitch = await governance.killSwitch\n")
                f.write(line.replace("await (await governance.killSwitch).activate(", "await killSwitch.activate("))
            
            # killSwitch deactivate
            elif "await (await governance.killSwitch).deactivate(" in line:
                indent = line[:len(line) - len(line.lstrip())]
                f.write(f"{indent}let killSwitch = await governance.killSwitch\n")
                f.write(line.replace("await (await governance.killSwitch).deactivate(", "await killSwitch.deactivate("))
                
            # killSwitch isWriteAllowed
            elif "let allowed = await (await governance.killSwitch).isWriteAllowed(" in line:
                indent = line[:len(line) - len(line.lstrip())]
                f.write(f"{indent}let killSwitch = await governance.killSwitch\n")
                f.write(line.replace("let allowed = await (await governance.killSwitch).isWriteAllowed(", "let allowed = await killSwitch.isWriteAllowed("))

            # killSwitch isWriteAllowed (return)
            elif "return await (await governance.killSwitch).isWriteAllowed(" in line:
                indent = line[:len(line) - len(line.lstrip())]
                f.write(f"{indent}let killSwitch = await governance.killSwitch\n")
                f.write(line.replace("return await (await governance.killSwitch).isWriteAllowed(", "return await killSwitch.isWriteAllowed("))

            # killSwitch killSwitchStatus
            elif "let status = await (await governance.killSwitch).killSwitchStatus()" in line:
                indent = line[:len(line) - len(line.lstrip())]
                f.write(f"{indent}let killSwitch = await governance.killSwitch\n")
                f.write(line.replace("let status = await (await governance.killSwitch).killSwitchStatus()", "let status = await killSwitch.killSwitchStatus()"))

            # killSwitch killSwitchStatus (return)
            elif "return await (await governance.killSwitch).killSwitchStatus()" in line:
                indent = line[:len(line) - len(line.lstrip())]
                f.write(f"{indent}let killSwitch = await governance.killSwitch\n")
                f.write(line.replace("return await (await governance.killSwitch).killSwitchStatus()", "return await killSwitch.killSwitchStatus()"))
                
            else:
                f.write(line)

print("Done")
