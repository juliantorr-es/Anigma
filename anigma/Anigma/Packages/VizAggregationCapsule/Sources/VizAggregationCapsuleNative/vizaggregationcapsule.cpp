#include "vizaggregationcapsule.hpp"
#include <algorithm>

std::string VizAggregationCapsuleNative::process(const std::string& input) {
    std::string result = input;
    std::reverse(result.begin(), result.end());
    return result;
}
