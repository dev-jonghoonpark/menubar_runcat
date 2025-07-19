/*
 Memory.swift
 Menubar RunCat

 Created by Jonghoon Park on 2025/07/19.
 Copyright © 2019 Takuto Nakamura. All rights reserved.
*/

import Foundation
import Darwin

typealias MemoryInfo = (value: Double, description: String)

final class Memory {
    static let `default` = MemoryInfo(0.0, " 0.0% ")

    func currentUsage() -> MemoryInfo {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return Memory.default
        }

        // 1. 페이지 크기
        let pageSize = UInt64(vm_kernel_page_size)

        // 2. 필요한 메모리 계산
        let active = UInt64(stats.active_count) * pageSize
        let speculative = UInt64(stats.speculative_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let purgeable = UInt64(stats.purgeable_count) * pageSize
        let external = UInt64(stats.external_page_count) * pageSize
        let used = active + inactive + speculative + wired + compressed - purgeable - external

        // 3. 총 물리 메모리 가져오기 (sysctl)
        var size: UInt64 = 0
        var sizeOfSize = MemoryLayout<UInt64>.size
        let result2 = sysctlbyname("hw.memsize", &size, &sizeOfSize, nil, 0)

        guard result2 == 0, size > 0 else {
            return Memory.default
        }

        let total = size

        // 4. 사용률 계산
        let value = min(99.9, (1000.0 * Double(used) / Double(total)).rounded() / 10.0)
        let description = String(format: "%4.1f%%", value)

        return MemoryInfo(value, description)
    }
}
