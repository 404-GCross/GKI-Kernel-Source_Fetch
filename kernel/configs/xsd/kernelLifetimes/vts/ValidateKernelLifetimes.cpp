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

#include <unistd.h>
#include <string>

#include <android-base/file.h>
#include <vintf/Version.h>
#include <vintf/VintfObject.h>
#include "utility/ValidateXml.h"

TEST(CheckConfig, kernelLifetimesValidation) {
    if (android::vintf::VintfObject::GetRuntimeInfo()->kernelVersion().dropMinor() <
        android::vintf::Version{4, 14}) {
        GTEST_SKIP() << "Kernel versions below 4.14 are exempt";
    }

    RecordProperty("description",
                   "Verify that the kernel EOL config file "
                   "is valid according to the schema");

    std::string xml_schema_path = android::base::GetExecutableDirectory() + "/kernel_lifetimes.xsd";
    std::vector<const char*> locations = {"/system/etc/kernel"};
    EXPECT_ONE_VALID_XML_MULTIPLE_LOCATIONS("kernel-lifetimes.xml", locations,
                                            xml_schema_path.c_str());
}
