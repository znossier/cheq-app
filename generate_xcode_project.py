#!/usr/bin/env python3
"""
Generate Xcode project.pbxproj file for FairShare iOS app
"""
import uuid
import os
from pathlib import Path

def generate_uuid():
    """Generate a 24-character uppercase hex string (Xcode format)"""
    return uuid.uuid4().hex[:24].upper()

# Generate UUIDs
project_uuid = generate_uuid()
target_uuid = generate_uuid()
config_list_uuid = generate_uuid()
debug_config_uuid = generate_uuid()
release_config_uuid = generate_uuid()
build_config_list_uuid = generate_uuid()
package_ref_uuid = generate_uuid()  # GoogleSignIn package reference
package_product_uuid = generate_uuid()  # GoogleSignIn product dependency

# File references
file_refs = {}
groups = {}
swift_files = []
build_file_map = {}  # Map file_uuid -> build_file_uuid

# Find all Swift files
base_path = Path(".")
for swift_file in sorted(base_path.rglob("*.swift")):
    if "Package.swift" in str(swift_file):
        continue
    rel_path = str(swift_file.relative_to(base_path))
    file_uuid = generate_uuid()
    build_file_uuid = generate_uuid()
    file_refs[rel_path] = file_uuid
    build_file_map[file_uuid] = build_file_uuid
    swift_files.append((rel_path, file_uuid))

# Create group structure
groups["Cheq"] = generate_uuid()
groups["Models"] = generate_uuid()
groups["Services"] = generate_uuid()
groups["ViewModels"] = generate_uuid()
groups["Views"] = generate_uuid()
groups["Utilities"] = generate_uuid()
groups["Extensions"] = generate_uuid()
groups["AssignItems"] = generate_uuid()
groups["Auth"] = generate_uuid()
groups["ConfirmReceipt"] = generate_uuid()
groups["Home"] = generate_uuid()
groups["Onboarding"] = generate_uuid()
groups["Scan"] = generate_uuid()
groups["Settings"] = generate_uuid()
groups["Splash"] = generate_uuid()
groups["Summary"] = generate_uuid()

# Build phases
sources_phase_uuid = generate_uuid()
frameworks_phase_uuid = generate_uuid()
resources_phase_uuid = generate_uuid()

# Additional UUIDs that need to be reused
products_group_uuid = generate_uuid()
root_group_uuid = generate_uuid()
project_object_uuid = generate_uuid()

# Generate project.pbxproj content
pbxproj = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
"""
# Add build file entries for Swift files
for rel_path, file_uuid in swift_files:
    build_file_uuid = build_file_map[file_uuid]
    pbxproj += f"""		{build_file_uuid} /* {Path(rel_path).name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {Path(rel_path).name} */; }};
"""

pbxproj += f"""/* End PBXBuildFile section */

/* Begin PBXFileReference section */
"""
# Add file references
for rel_path, file_uuid in swift_files:
    pbxproj += f"""		{file_uuid} /* {Path(rel_path).name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{rel_path}"; sourceTree = "<group>"; }};
"""

pbxproj += f"""		{config_list_uuid} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
		{project_uuid} /* FairShare.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = FairShare.app; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_phase_uuid} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{groups["FairShare"]} /* FairShare */ = {{
			isa = PBXGroup;
			children = (
				{groups["Models"]} /* Models */,
				{groups["Services"]} /* Services */,
				{groups["ViewModels"]} /* ViewModels */,
				{groups["Views"]} /* Views */,
				{groups["Utilities"]} /* Utilities */,
				{file_refs.get("FairShareApp.swift", generate_uuid())} /* FairShareApp.swift */,
				{file_refs.get("ContentView.swift", generate_uuid())} /* ContentView.swift */,
				{config_list_uuid} /* Info.plist */,
			);
			sourceTree = "<group>";
		}};
		{groups["Models"]} /* Models */ = {{
			isa = PBXGroup;
			children = (
"""
for rel_path, file_uuid in swift_files:
    if rel_path.startswith("Models/"):
        pbxproj += f"""				{file_uuid} /* {Path(rel_path).name} */,
"""
pbxproj += f"""			);
			path = Models;
			sourceTree = "<group>";
		}};
		{groups["Services"]} /* Services */ = {{
			isa = PBXGroup;
			children = (
"""
for rel_path, file_uuid in swift_files:
    if rel_path.startswith("Services/"):
        pbxproj += f"""				{file_uuid} /* {Path(rel_path).name} */,
"""
pbxproj += f"""			);
			path = Services;
			sourceTree = "<group>";
		}};
		{groups["ViewModels"]} /* ViewModels */ = {{
			isa = PBXGroup;
			children = (
"""
for rel_path, file_uuid in swift_files:
    if rel_path.startswith("ViewModels/"):
        pbxproj += f"""				{file_uuid} /* {Path(rel_path).name} */,
"""
pbxproj += f"""			);
			path = ViewModels;
			sourceTree = "<group>";
		}};
		{groups["Views"]} /* Views */ = {{
			isa = PBXGroup;
			children = (
				{groups["AssignItems"]} /* AssignItems */,
				{groups["Auth"]} /* Auth */,
				{groups["ConfirmReceipt"]} /* ConfirmReceipt */,
				{groups["Home"]} /* Home */,
				{groups["Onboarding"]} /* Onboarding */,
				{groups["Scan"]} /* Scan */,
				{groups["Settings"]} /* Settings */,
				{groups["Splash"]} /* Splash */,
				{groups["Summary"]} /* Summary */,
			);
			path = Views;
			sourceTree = "<group>";
		}};
		{groups["AssignItems"]} /* AssignItems */ = {{
			isa = PBXGroup;
			children = (
"""
for rel_path, file_uuid in swift_files:
    if rel_path.startswith("Views/AssignItems/"):
        pbxproj += f"""				{file_uuid} /* {Path(rel_path).name} */,
"""
pbxproj += f"""			);
			path = AssignItems;
			sourceTree = "<group>";
		}};
		{groups["Auth"]} /* Auth */ = {{
			isa = PBXGroup;
			children = (
"""
for rel_path, file_uuid in swift_files:
    if rel_path.startswith("Views/Auth/"):
        pbxproj += f"""				{file_uuid} /* {Path(rel_path).name} */,
"""
pbxproj += f"""			);
			path = Auth;
			sourceTree = "<group>";
		}};
		{groups["ConfirmReceipt"]} /* ConfirmReceipt */ = {{
			isa = PBXGroup;
			children = (
"""
for rel_path, file_uuid in swift_files:
    if rel_path.startswith("Views/ConfirmReceipt/"):
        pbxproj += f"""				{file_uuid} /* {Path(rel_path).name} */,
"""
pbxproj += f"""			);
			path = ConfirmReceipt;
			sourceTree = "<group>";
		}};
		{groups["Home"]} /* Home */ = {{
			isa = PBXGroup;
			children = (
"""
for rel_path, file_uuid in swift_files:
    if rel_path.startswith("Views/Home/"):
        pbxproj += f"""				{file_uuid} /* {Path(rel_path).name} */,
"""
pbxproj += f"""			);
			path = Home;
			sourceTree = "<group>";
		}};
		{groups["Onboarding"]} /* Onboarding */ = {{
			isa = PBXGroup;
			children = (
"""
for rel_path, file_uuid in swift_files:
    if rel_path.startswith("Views/Onboarding/"):
        pbxproj += f"""				{file_uuid} /* {Path(rel_path).name} */,
"""
pbxproj += f"""			);
			path = Onboarding;
			sourceTree = "<group>";
		}};
		{groups["Scan"]} /* Scan */ = {{
			isa = PBXGroup;
			children = (
"""
for rel_path, file_uuid in swift_files:
    if rel_path.startswith("Views/Scan/"):
        pbxproj += f"""				{file_uuid} /* {Path(rel_path).name} */,
"""
pbxproj += f"""			);
			path = Scan;
			sourceTree = "<group>";
		}};
		{groups["Settings"]} /* Settings */ = {{
			isa = PBXGroup;
			children = (
"""
for rel_path, file_uuid in swift_files:
    if rel_path.startswith("Views/Settings/"):
        pbxproj += f"""				{file_uuid} /* {Path(rel_path).name} */,
"""
pbxproj += f"""			);
			path = Settings;
			sourceTree = "<group>";
		}};
		{groups["Splash"]} /* Splash */ = {{
			isa = PBXGroup;
			children = (
"""
for rel_path, file_uuid in swift_files:
    if rel_path.startswith("Views/Splash/"):
        pbxproj += f"""				{file_uuid} /* {Path(rel_path).name} */,
"""
pbxproj += f"""			);
			path = Splash;
			sourceTree = "<group>";
		}};
		{groups["Summary"]} /* Summary */ = {{
			isa = PBXGroup;
			children = (
"""
for rel_path, file_uuid in swift_files:
    if rel_path.startswith("Views/Summary/"):
        pbxproj += f"""				{file_uuid} /* {Path(rel_path).name} */,
"""
pbxproj += f"""			);
			path = Summary;
			sourceTree = "<group>";
		}};
		{groups["Utilities"]} /* Utilities */ = {{
			isa = PBXGroup;
			children = (
				{groups["Extensions"]} /* Extensions */,
				{file_refs.get("Utilities/Constants.swift", generate_uuid())} /* Constants.swift */,
			);
			path = Utilities;
			sourceTree = "<group>";
		}};
		{groups["Extensions"]} /* Extensions */ = {{
			isa = PBXGroup;
			children = (
"""
for rel_path, file_uuid in swift_files:
    if rel_path.startswith("Utilities/Extensions/"):
        pbxproj += f"""				{file_uuid} /* {Path(rel_path).name} */,
"""
pbxproj += f"""			);
			path = Extensions;
			sourceTree = "<group>";
		}};
		{products_group_uuid} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{project_uuid} /* FairShare.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
		{root_group_uuid} = {{
			isa = PBXGroup;
			children = (
				{groups["FairShare"]} /* FairShare */,
				{products_group_uuid} /* Products */,
			);
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target_uuid} /* FairShare */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {build_config_list_uuid} /* Build configuration list for PBXNativeTarget "FairShare" */;
			buildPhases = (
				{sources_phase_uuid} /* Sources */,
				{frameworks_phase_uuid} /* Frameworks */,
				{resources_phase_uuid} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = FairShare;
			packageProductDependencies = (
				{package_product_uuid} /* GoogleSignIn */,
			);
			productName = FairShare;
			productReference = {project_uuid} /* FairShare.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project_object_uuid} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {{
					{target_uuid} = {{
						CreatedOnToolsVersion = 15.0;
					}};
				}};
			}};
			buildConfigurationList = {config_list_uuid} /* Build configuration list for PBXProject "FairShare" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {root_group_uuid};
			packageReferences = (
				{package_ref_uuid} /* XCRemoteSwiftPackageReference "GoogleSignIn-iOS" */,
			);
			productRefGroup = {products_group_uuid} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target_uuid} /* FairShare */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_phase_uuid} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{generate_uuid()} /* Info.plist in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources_phase_uuid} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
"""
# Add source files to build phase
for rel_path, file_uuid in swift_files:
    build_file_uuid = build_file_map[file_uuid]
    pbxproj += f"""				{build_file_uuid} /* {Path(rel_path).name} in Sources */,
"""

pbxproj += f"""			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{debug_config_uuid} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Info.plist;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 18.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.fairshare.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = Debug;
		}};
		{release_config_uuid} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Info.plist;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 18.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.fairshare.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{build_config_list_uuid} /* Build configuration list for PBXNativeTarget "FairShare" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_config_uuid} /* Debug */,
				{release_config_uuid} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{config_list_uuid} /* Build configuration list for PBXProject "FairShare" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_config_uuid} /* Debug */,
				{release_config_uuid} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

/* Begin XCRemoteSwiftPackageReference section */
		{package_ref_uuid} /* XCRemoteSwiftPackageReference "GoogleSignIn-iOS" */ = {{
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/google/GoogleSignIn-iOS";
			requirement = {{
				kind = upToNextMajorVersion;
				minimumVersion = 7.0.0;
			}};
		}};
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		{package_product_uuid} /* GoogleSignIn */ = {{
			isa = XCSwiftPackageProductDependency;
			package = {package_ref_uuid} /* XCRemoteSwiftPackageReference "GoogleSignIn-iOS" */;
			productName = GoogleSignIn;
		}};
/* End XCSwiftPackageProductDependency section */
	}};
	rootObject = {project_object_uuid} /* Project object */;
}}
"""

print(pbxproj)

