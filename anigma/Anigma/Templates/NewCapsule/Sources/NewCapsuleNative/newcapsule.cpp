#include "newcapsule.hpp"
#include <algorithm>

std::string NewCapsuleNative::process(const std::string& input) {
    std::string result = input;
    std::reverse(result.begin(), result.end());
    return result;
}
