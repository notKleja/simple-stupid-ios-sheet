#!/usr/bin/env python3
"""Generate only reproducible Xcode scaffolding under ignored build/."""
import hashlib
from pathlib import Path
import plistlib
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/NativeInteractions.xcodeproj"
OUT.mkdir(parents=True, exist_ok=True)
objects = {}

def add(seed, isa, **fields):
    key = hashlib.sha1(seed.encode()).hexdigest()[:24].upper()
    objects[key] = {"isa":isa, **fields}
    return key

app_name, tests_name = "NativeSheetHarness", "NativeInteractionUITests"
app_product = add("app-product", "PBXFileReference", explicitFileType="wrapper.application", path=app_name+".app", sourceTree="BUILT_PRODUCTS_DIR")
test_product = add("test-product", "PBXFileReference", explicitFileType="wrapper.cfbundle", path=tests_name+".xctest", sourceTree="BUILT_PRODUCTS_DIR")
refs, app_files = [], []
for path in sorted((ROOT/"native_reference/NativeSheetHarness").glob("*.swift")):
    ref = add(str(path), "PBXFileReference", lastKnownFileType="sourcecode.swift", path=str(path), sourceTree="<absolute>")
    refs.append(ref); app_files.append(add(str(path)+"-build", "PBXBuildFile", fileRef=ref))
test_path = ROOT/"native_reference/XCTests/NativeInteractionUITests.swift"
test_ref = add("test-source", "PBXFileReference", lastKnownFileType="sourcecode.swift", path=str(test_path), sourceTree="<absolute>")
refs.append(test_ref)
test_file = add("test-source-build", "PBXBuildFile", fileRef=test_ref)
geometry_test_files = []
for seed, path in [("geometry-contract", ROOT/"native_reference/tests/GeometryProbeContractTests.swift"),
                   ("geometry-probe", ROOT/"native_reference/NativeSheetHarness/GeometryProbe.swift")]:
    ref = add(seed, "PBXFileReference", lastKnownFileType="sourcecode.swift", path=str(path), sourceTree="<absolute>")
    refs.append(ref);geometry_test_files.append(add(seed+"-build", "PBXBuildFile", fileRef=ref))
products = add("products", "PBXGroup", children=[app_product,test_product], name="Products", sourceTree="<group>")
group = add("root-group", "PBXGroup", children=refs+[products], sourceTree="<group>")
project_id = hashlib.sha1(b"project").hexdigest()[:24].upper()
app_id = hashlib.sha1(b"app-target").hexdigest()[:24].upper()
proxy = add("app-proxy", "PBXContainerItemProxy", containerPortal=project_id, proxyType=1, remoteGlobalIDString=app_id, remoteInfo=app_name)
dependency = add("app-dependency", "PBXTargetDependency", target=app_id, targetProxy=proxy)
shared = {"SDKROOT":"iphoneos", "IPHONEOS_DEPLOYMENT_TARGET":"26.0", "SWIFT_VERSION":"5.0", "CLANG_ENABLE_MODULES":"YES", "TARGETED_DEVICE_FAMILY":"1,2", "CODE_SIGNING_ALLOWED":"NO", "PRODUCT_NAME":"$(TARGET_NAME)", "SWIFT_OPTIMIZATION_LEVEL":"-Onone"}

def configurations(name, extra):
    configs = [add(name+kind,"XCBuildConfiguration",name=kind,buildSettings={**shared,**extra}) for kind in ["Debug","Release"]]
    return add(name+"configs","XCConfigurationList",buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName="Debug")

app_config = configurations("app", {"PRODUCT_BUNDLE_IDENTIFIER":"dev.notkleja.NativeSheetHarness", "INFOPLIST_FILE":str(ROOT/"native_reference/NativeSheetHarness/Info.plist"), "LD_RUNPATH_SEARCH_PATHS":"$(inherited) @executable_path/Frameworks", "OTHER_LDFLAGS":"$(inherited) -framework UIKit -framework QuartzCore -framework SwiftUI"})
revision = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
test_plist = ROOT/'build/NativeInteractionTestInfo.plist'
test_plist.write_bytes(plistlib.dumps({'CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleExecutable':'$(EXECUTABLE_NAME)',
    'CFBundleName':'$(PRODUCT_NAME)','CFBundlePackageType':'BNDL','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','NativeSourceRevision':revision}))
test_config = configurations("tests", {"PRODUCT_BUNDLE_IDENTIFIER":"dev.notkleja.NativeSheetHarnessUITests", "GENERATE_INFOPLIST_FILE":"NO", "INFOPLIST_FILE":str(test_plist), "TEST_TARGET_NAME":app_name, "LD_RUNPATH_SEARCH_PATHS":"$(inherited) @executable_path/Frameworks @loader_path/Frameworks"})
app_sources = add("app-sources","PBXSourcesBuildPhase",buildActionMask=2147483647,files=app_files,runOnlyForDeploymentPostprocessing=0)
test_sources = add("test-sources","PBXSourcesBuildPhase",buildActionMask=2147483647,files=[test_file]+geometry_test_files,runOnlyForDeploymentPostprocessing=0)
app_frameworks = add("app-frameworks","PBXFrameworksBuildPhase",buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
test_frameworks = add("test-frameworks","PBXFrameworksBuildPhase",buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
add("app-target","PBXNativeTarget",buildConfigurationList=app_config,buildPhases=[app_sources,app_frameworks],buildRules=[],dependencies=[],name=app_name,productName=app_name,productReference=app_product,productType="com.apple.product-type.application")
test_id = add("test-target","PBXNativeTarget",buildConfigurationList=test_config,buildPhases=[test_sources,test_frameworks],buildRules=[],dependencies=[dependency],name=tests_name,productName=tests_name,productReference=test_product,productType="com.apple.product-type.bundle.ui-testing")
project_config = configurations("project", {})
objects[project_id] = {"isa":"PBXProject", "attributes":{"LastUpgradeCheck":"2700", "TargetAttributes":{test_id:{"TestTargetID":app_id}}}, "buildConfigurationList":project_config, "compatibilityVersion":"Xcode 14.0", "developmentRegion":"en", "hasScannedForEncodings":0, "knownRegions":["en","Base"], "mainGroup":group, "productRefGroup":products, "projectDirPath":"", "projectRoot":"", "targets":[app_id,test_id]}
def legacy_types(value):
    if isinstance(value, dict): return {key:legacy_types(item) for key,item in value.items()}
    if isinstance(value, list): return [legacy_types(item) for item in value]
    return str(value) if isinstance(value, int) else value
(OUT/"project.pbxproj").write_bytes(plistlib.dumps(legacy_types({"archiveVersion":1,"classes":{},"objectVersion":56,"objects":objects,"rootObject":project_id})))
schemes=OUT/"xcshareddata/xcschemes"; schemes.mkdir(parents=True,exist_ok=True)
def ref(key,name,ext): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{key}" BuildableName="{name}.{ext}" BlueprintName="{name}" ReferencedContainer="container:NativeInteractions.xcodeproj"/>'
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="NO" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{ref(app_id,app_name,"app")}</BuildActionEntry><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{ref(test_id,tests_name,"xctest")}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref(test_id,tests_name,"xctest")}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0"><BuildableProductRunnable runnableDebuggingMode="0">{ref(app_id,app_name,"app")}</BuildableProductRunnable></LaunchAction></Scheme>'''
(schemes/"NativeInteractions.xcscheme").write_text(scheme)
print(OUT)
