#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
test_dir=$(mktemp -d /tmp/human-checks.XXXXXX)
print "Test executables: $test_dir"
xcrun swiftc HumanHydration/Models/HydrationEntry.swift Tests/StatisticsChecks.swift -o "$test_dir/statistics"
"$test_dir/statistics"
xcrun swiftc HumanHydration/Services/AuthService.swift HumanHydration/Services/AppConfig.swift HumanHydration/Services/SessionVault.swift HumanHydration/Services/AccountStorage.swift HumanHydration/Services/HydrationStore.swift HumanHydration/Models/HydrationEntry.swift HumanHydration/Shared/HydrationWidgetData.swift Tests/AuthChecks.swift -o "$test_dir/auth"
"$test_dir/auth"
xcrun swiftc HumanHydration/Shared/HydrationWidgetData.swift Tests/WidgetDataChecks.swift -o "$test_dir/widgets"
"$test_dir/widgets"
