/*
 * Copyright (C) 2024 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <android-base/file.h>
#include <kver/kernel_release.h>
#include <unistd.h>
#include <vintf/VintfObject.h>

#include <string>

#include "utility/ValidateXml.h"

TEST(CheckConfig, approvedBuildValidation) {
  const auto kernel_release = android::kver::KernelRelease::Parse(
      android::vintf::VintfObject::GetRuntimeInfo()->osRelease(),
      /* allow_suffix = */ true);
  if (!kernel_release.has_value()) {
    GTEST_FAIL() << "Failed to parse the kernel release string";
  }
  if (kernel_release->android_release() < 14) {
    GTEST_SKIP() << "Kernel releases below android14 are exempt";
  }

  RecordProperty("description",
                 "Verify that the approved OGKI builds file "
                 "is valid according to the schema");

  std::string xml_schema_path =
      android::base::GetExecutableDirectory() + "/approved_build.xsd";
  std::vector<const char*> locations = {"/system/etc/kernel"};
  EXPECT_ONE_VALID_XML_MULTIPLE_LOCATIONS("approved-ogki-builds.xml", locations,
                                          xml_schema_path.c_str());
}
