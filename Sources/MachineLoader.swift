//
//  MachineLoaderr.swift
//  TinyEMU-iOS
//
//  Created by Fernando Lemos on 3/31/19.
//

import Foundation


class MachineLoader {

    enum MachineLoaderError: Error {
        case missingDescription
        case invalidDescription
    }

    private struct MachineDescription: Codable {
        var bios: String
        var kernel: String?
        var kernelCommandLine: String?
        var rootDrive: String?

        private enum CodingKeys: String, CodingKey {
            case bios = "BIOS"
            case kernel = "Kernel"
            case kernelCommandLine = "KernelCommandLine"
            case rootDrive = "RootDrive"
        }
    }

    let configFileURL: URL

    init() {
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(),
                                        isDirectory: true)
        configFileURL = temporaryDirectoryURL.appendingPathComponent("temu.cfg")
    }

    deinit {
        try? FileManager.default.removeItem(at: configFileURL)
    }

    func load(_ bundle: Bundle) throws {
        guard let plistURL = bundle.url(forResource: "Machine",
                                         withExtension: "plist") else {
            throw MachineLoaderError.missingDescription
        }
        let plistData = try Data(contentsOf: plistURL)

        let decoder = PropertyListDecoder()
        let description = try decoder.decode(MachineDescription.self, from: plistData)

        var config = """
{
    version: 1,
    machine: "riscv64",
    memory_size: 128,

"""
        config += "    bios: \"\(bundle.bundlePath)/\(description.bios)\",\n"
        if let kernel = description.kernel {
            config += "    kernel: \"\(bundle.bundlePath)/\(kernel)\",\n"
        }
        if let commandLine = description.kernelCommandLine {
            config += "    cmdline: \"\(commandLine)\",\n"
        }
        if let rootDrive = description.rootDrive {
            config += "    drive0: { file: \"\(bundle.bundlePath)/\(rootDrive)\" },\n"
        }
        config += """
    eth0: { driver: "user" },
}
"""
        try config.write(to: configFileURL,
                         atomically: true,
                         encoding: .utf8)
    }
}
