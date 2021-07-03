Pod::Spec.new do |spec|
  spec.name         = "DeltaCore"
  spec.version      = "0.1"
  spec.summary      = "iOS Emulator Plug-in Framework"
  spec.description  = "iOS framework that powers Delta emulator."
  spec.homepage     = "https://github.com/rileytestut/DeltaCore"
  spec.platform     = :ios, "12.0"
  spec.source       = { :git => "https://github.com/rileytestut/DeltaCore.git" }

  spec.author             = { "Riley Testut" => "riley@rileytestut.com" }
  spec.social_media_url   = "https://twitter.com/rileytestut"
  
  spec.source_files  = "DeltaCore/**/*.{h,m,swift}"
  spec.exclude_files = "DeltaCore/DeltaTypes.h", "DeltaCore/Emulator Core/Audio/DLTAMuteSwitchMonitor.h"
  spec.public_header_files = "DeltaCore/include/*.h"
  spec.resource_bundles = {
    "DeltaCore" => ["DeltaCore/**/*.deltamapping"]
  }
  
  spec.dependency "ZIPFoundation"
  
  spec.xcconfig = {
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS" => "STATIC_LIBRARY",
    "OTHER_CFLAGS" => "-DSTATIC_LIBRARY"
  }
  
  spec.script_phase = { :name => 'Copy Swift Header', :script => <<-SCRIPT
target_dir=${BUILT_PRODUCTS_DIR}

mkdir -p ${target_dir}

# Copy any file that looks like a Swift generated header to the include path
cp ${DERIVED_SOURCES_DIR}/*-Swift.h ${target_dir}
SCRIPT
  }
  
end
