#!/usr/bin/env python3
"""
Regenerate Xcode project file from scratch
Ensures Core Data model is properly included in Resources
"""

import uuid
import os
from pathlib import Path

def generate_uuid():
    """Generate a 24-character uppercase hex UUID for Xcode"""
    return uuid.uuid4().hex[:24].upper()

# Generate all UUIDs needed
project_uuid = generate_uuid()
target_uuid = generate_uuid()
config_list_uuid = generate_uuid()
debug_config_uuid = generate_uuid()
release_config_uuid = generate_uuid()
build_config_list_uuid = generate_uuid()
package_ref_uuid = generate_uuid()
package_product_uuid = generate_uuid()

# Build phases
sources_phase_uuid = generate_uuid()
frameworks_phase_uuid = generate_uuid()
resources_phase_uuid = generate_uuid()

# Groups
root_group_uuid = generate_uuid()
products_group_uuid = generate_uuid()
models_group_uuid = generate_uuid()
services_group_uuid = generate_uuid()
viewmodels_group_uuid = generate_uuid()
views_group_uuid = generate_uuid()
utilities_group_uuid = generate_uuid()
extensions_group_uuid = generate_uuid()
designsystem_group_uuid = generate_uuid()
assignitems_group_uuid = generate_uuid()
auth_group_uuid = generate_uuid()
confirmreceipt_group_uuid = generate_uuid()
home_group_uuid = generate_uuid()
onboarding_group_uuid = generate_uuid()
scan_group_uuid = generate_uuid()
settings_group_uuid = generate_uuid()
splash_group_uuid = generate_uuid()
summary_group_uuid = generate_uuid()

# File references and build files
file_refs = {}
build_files = {}

# Find all Swift files
base_path = Path(".")
swift_files = []
for swift_file in sorted(base_path.rglob("*.swift")):
    if "Package.swift" in str(swift_file):
        continue
    rel_path = str(swift_file.relative_to(base_path))
    swift_files.append(rel_path)

# Create file references and build files for Swift files
for swift_file in swift_files:
    file_uuid = generate_uuid()
    build_file_uuid = generate_uuid()
    file_refs[swift_file] = (file_uuid, build_file_uuid)

# Special files
assets_uuid = generate_uuid()
assets_build_uuid = generate_uuid()
model_uuid = generate_uuid()
model_build_uuid = generate_uuid()
infoplist_uuid = generate_uuid()
entitlements_uuid = generate_uuid()
app_uuid = generate_uuid()

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

# Add build files for Swift files
for swift_file in swift_files:
    file_uuid, build_file_uuid = file_refs[swift_file]
    filename = Path(swift_file).name
    pbxproj += f"""		{build_file_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {filename} */; }};
"""

# Add build files for resources
pbxproj += f"""		{assets_build_uuid} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_uuid} /* Assets.xcassets */; }};
		{model_build_uuid} /* Cheq.xcdatamodeld in Resources */ = {{isa = PBXBuildFile; fileRef = {model_uuid} /* Cheq.xcdatamodeld */; }};
		{package_product_uuid} /* GoogleSignIn in Frameworks */ = {{isa = PBXBuildFile; productRef = {package_product_uuid} /* GoogleSignIn */; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
"""

# Add file references for Swift files
for swift_file in swift_files:
    file_uuid, _ = file_refs[swift_file]
    filename = Path(swift_file).name
    pbxproj += f"""		{file_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{swift_file}"; sourceTree = "<group>"; }};
"""

# Add special file references
pbxproj += f"""		{assets_uuid} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};
		{model_uuid} /* Cheq.xcdatamodeld */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.xcdatamodel; path = Cheq.xcdatamodeld; sourceTree = "<group>"; }};
		{infoplist_uuid} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
		{entitlements_uuid} /* Cheq.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Cheq.entitlements; sourceTree = "<group>"; }};
		{app_uuid} /* Cheq.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Cheq.app; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_phase_uuid} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{package_product_uuid} /* GoogleSignIn in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{root_group_uuid} = {{
			isa = PBXGroup;
			children = (
				{models_group_uuid} /* Models */,
				{services_group_uuid} /* Services */,
				{viewmodels_group_uuid} /* ViewModels */,
				{views_group_uuid} /* Views */,
				{utilities_group_uuid} /* Utilities */,
				{file_refs["CheqApp.swift"][0]} /* CheqApp.swift */,
				{file_refs["ContentView.swift"][0]} /* ContentView.swift */,
				{assets_uuid} /* Assets.xcassets */,
				{model_uuid} /* Cheq.xcdatamodeld */,
				{infoplist_uuid} /* Info.plist */,
				{entitlements_uuid} /* Cheq.entitlements */,
			);
			sourceTree = "<group>";
		}};
		{products_group_uuid} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{app_uuid} /* Cheq.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
"""

# Add Models group
pbxproj += f"""		{models_group_uuid} /* Models */ = {{
			isa = PBXGroup;
			children = (
"""
for swift_file in sorted([f for f in swift_files if f.startswith("Models/")]):
    file_uuid, _ = file_refs[swift_file]
    filename = Path(swift_file).name
    pbxproj += f"""				{file_uuid} /* {filename} */,
"""
pbxproj += """			);
			path = Models;
			sourceTree = "<group>";
		};
"""

# Add Services group
pbxproj += f"""		{services_group_uuid} /* Services */ = {{
			isa = PBXGroup;
			children = (
"""
for swift_file in sorted([f for f in swift_files if f.startswith("Services/")]):
    file_uuid, _ = file_refs[swift_file]
    filename = Path(swift_file).name
    pbxproj += f"""				{file_uuid} /* {filename} */,
"""
pbxproj += """			);
			path = Services;
			sourceTree = "<group>";
		};
"""

# Add ViewModels group
pbxproj += f"""		{viewmodels_group_uuid} /* ViewModels */ = {{
			isa = PBXGroup;
			children = (
"""
for swift_file in sorted([f for f in swift_files if f.startswith("ViewModels/")]):
    file_uuid, _ = file_refs[swift_file]
    filename = Path(swift_file).name
    pbxproj += f"""				{file_uuid} /* {filename} */,
"""
pbxproj += """			);
			path = ViewModels;
			sourceTree = "<group>";
		};
"""

# Add Views group with sub-groups
pbxproj += f"""		{views_group_uuid} /* Views */ = {{
			isa = PBXGroup;
			children = (
				{assignitems_group_uuid} /* AssignItems */,
				{auth_group_uuid} /* Auth */,
				{confirmreceipt_group_uuid} /* ConfirmReceipt */,
				{home_group_uuid} /* Home */,
				{onboarding_group_uuid} /* Onboarding */,
				{scan_group_uuid} /* Scan */,
				{settings_group_uuid} /* Settings */,
				{splash_group_uuid} /* Splash */,
				{summary_group_uuid} /* Summary */,
			);
			path = Views;
			sourceTree = "<group>";
		}};
"""

# Add view sub-groups
for group_name, group_uuid, path_prefix in [
    ("AssignItems", assignitems_group_uuid, "Views/AssignItems/"),
    ("Auth", auth_group_uuid, "Views/Auth/"),
    ("ConfirmReceipt", confirmreceipt_group_uuid, "Views/ConfirmReceipt/"),
    ("Home", home_group_uuid, "Views/Home/"),
    ("Onboarding", onboarding_group_uuid, "Views/Onboarding/"),
    ("Scan", scan_group_uuid, "Views/Scan/"),
    ("Settings", settings_group_uuid, "Views/Settings/"),
    ("Splash", splash_group_uuid, "Views/Splash/"),
    ("Summary", summary_group_uuid, "Views/Summary/"),
]:
    pbxproj += f"""		{group_uuid} /* {group_name} */ = {{
			isa = PBXGroup;
			children = (
"""
    for swift_file in sorted([f for f in swift_files if f.startswith(path_prefix)]):
        file_uuid, _ = file_refs[swift_file]
        filename = Path(swift_file).name
        pbxproj += f"""				{file_uuid} /* {filename} */,
"""
    pbxproj += f"""			);
			path = {group_name};
			sourceTree = "<group>";
		}};
"""

# Add Utilities group with sub-groups
pbxproj += f"""		{utilities_group_uuid} /* Utilities */ = {{
			isa = PBXGroup;
			children = (
				{designsystem_group_uuid} /* DesignSystem */,
				{extensions_group_uuid} /* Extensions */,
"""
for swift_file in sorted([f for f in swift_files if f.startswith("Utilities/") and "/" not in f[10:]]):
    file_uuid, _ = file_refs[swift_file]
    filename = Path(swift_file).name
    pbxproj += f"""				{file_uuid} /* {filename} */,
"""
pbxproj += """			);
			path = Utilities;
			sourceTree = "<group>";
		};
"""

# Add DesignSystem group
pbxproj += f"""		{designsystem_group_uuid} /* DesignSystem */ = {{
			isa = PBXGroup;
			children = (
"""
for swift_file in sorted([f for f in swift_files if f.startswith("Utilities/DesignSystem/")]):
    file_uuid, _ = file_refs[swift_file]
    filename = Path(swift_file).name
    pbxproj += f"""				{file_uuid} /* {filename} */,
"""
pbxproj += """			);
			path = DesignSystem;
			sourceTree = "<group>";
		};
"""

# Add Extensions group
pbxproj += f"""		{extensions_group_uuid} /* Extensions */ = {{
			isa = PBXGroup;
			children = (
"""
for swift_file in sorted([f for f in swift_files if f.startswith("Utilities/Extensions/")]):
    file_uuid, _ = file_refs[swift_file]
    filename = Path(swift_file).name
    pbxproj += f"""				{file_uuid} /* {filename} */,
"""
pbxproj += """			);
			path = Extensions;
			sourceTree = "<group>";
		}};
"""

# Add root group
pbxproj += f"""		9CB980CE2BB74F28A2033EC0 = {{
			isa = PBXGroup;
			children = (
				{root_group_uuid},
				{products_group_uuid} /* Products */,
			);
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target_uuid} /* Cheq */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {build_config_list_uuid} /* Build configuration list for PBXNativeTarget "Cheq" */;
			buildPhases = (
				{sources_phase_uuid} /* Sources */,
				{frameworks_phase_uuid} /* Frameworks */,
				{resources_phase_uuid} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = Cheq;
			packageProductDependencies = (
				{package_product_uuid} /* GoogleSignIn */,
			);
			productName = Cheq;
			productReference = {app_uuid} /* Cheq.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project_uuid} /* Project object */ = {{
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
			buildConfigurationList = {config_list_uuid} /* Build configuration list for PBXProject "Cheq" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 9CB980CE2BB74F28A2033EC0;
			packageReferences = (
				{package_ref_uuid} /* XCRemoteSwiftPackageReference "GoogleSignIn-iOS" */,
			);
			productRefGroup = {products_group_uuid} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target_uuid} /* Cheq */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_phase_uuid} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{assets_build_uuid} /* Assets.xcassets in Resources */,
				{model_build_uuid} /* Cheq.xcdatamodeld in Resources */,
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

# Add all Swift files to Sources
for swift_file in sorted(swift_files):
    _, build_file_uuid = file_refs[swift_file]
    filename = Path(swift_file).name
    pbxproj += f"""				{build_file_uuid} /* {filename} in Sources */,
"""

pbxproj += f"""			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{release_config_uuid} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = NO;
				CODE_SIGN_ENTITLEMENTS = Cheq.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				DEVELOPMENT_TEAM = HFQ8UWKULA;
				ENABLE_PREVIEWS = YES;
				"EXCLUDED_ARCHS[sdk=iphonesimulator*]" = x86_64;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = Cheq;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.finance";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.zeinanosier.cheq;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;
				SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
				USE_HEADERMAP = separate;
			}};
			name = Release;
		}};
		{debug_config_uuid} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = NO;
				CODE_SIGN_ENTITLEMENTS = Cheq.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				DEVELOPMENT_TEAM = HFQ8UWKULA;
				ENABLE_PREVIEWS = YES;
				"EXCLUDED_ARCHS[sdk=iphonesimulator*]" = x86_64;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = Cheq;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.finance";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.zeinanosier.cheq;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;
				SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
				USE_HEADERMAP = separate;
			}};
			name = Debug;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{config_list_uuid} /* Build configuration list for PBXProject "Cheq" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_config_uuid} /* Debug */,
				{release_config_uuid} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{build_config_list_uuid} /* Build configuration list for PBXNativeTarget "Cheq" */ = {{
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
	rootObject = {project_uuid} /* Project object */;
"""
pbxproj += "}\n"

# Write the project file
output_path = Path("Cheq.xcodeproj/project.pbxproj")
output_path.write_text(pbxproj)
print(f"✅ Successfully regenerated {output_path}")
print(f"   - Included {len(swift_files)} Swift files")
print(f"   - Core Data model properly added to Resources")
print(f"   - All build settings preserved")

