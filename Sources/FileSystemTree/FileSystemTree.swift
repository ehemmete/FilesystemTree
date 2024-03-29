// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation

public struct FileSystemTree {
    
    public init() { }
    
    public struct entry {
        var url: URL
        var type: String
        var parentURL: URL
        var isHidden: Bool
    }
    
    public func getContentsText(directory: URL, prefix: String, showHiddenFiles: Bool) throws -> ([String], Int, Int) {
        var directoryCount = 0
        var fileCount = 0
        var output: [String] = []
        let fileManager = FileManager.default
        let paths = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey]).sorted { $0.path < $1.path }
        for index in 0..<paths.count {
            let path = paths[index]
            if try !path.resourceValues(forKeys: [.isHiddenKey]).isHidden! || showHiddenFiles {
                var horizontal = ""
                var vertical = ""
                
                if index == paths.count - 1 {
                    horizontal = "└── "
                    vertical = "    "
                } else {
                    horizontal = "├── "
                    vertical = "│   "
                }
                
                let line = prefix + horizontal + path.lastPathComponent
                output.append(line)
                
                if try path.resourceValues(forKeys: [.isDirectoryKey]).isDirectory! {
                    directoryCount += 1
                    let newData = try getContentsText(directory: path, prefix: (prefix + vertical), showHiddenFiles: showHiddenFiles)
                    output.append(contentsOf: newData.0)
                    directoryCount = directoryCount + newData.1
                    fileCount = fileCount + newData.2
                } else {
                    fileCount += 1
                }
            }
        }
        return (output, directoryCount, fileCount)
    }
    
    public func getContentsHTML(entryArray: [entry], parentFolderURL: URL, showHiddenFiles: Bool) throws -> ([String], Int, Int) {
        var directoryCount = 0
        var fileCount = 0
        var output: [String] = []
        let folderContents = entryArray.filter { $0.parentURL.path == parentFolderURL.path }
        if !folderContents.isEmpty {
            try folderContents.forEach { item in
                if item.type == "directory" {
                    directoryCount += 1
                    var contents: [URL] = []
                    if showHiddenFiles {
                        contents = try FileManager.default.contentsOfDirectory(at: item.url, includingPropertiesForKeys: nil)
                    } else {
                        contents = try FileManager.default.contentsOfDirectory(at: item.url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                    }
                    if contents.isEmpty {
                        output.append("<details><summary>\(item.url.lastPathComponent)</summary></details>")
                    } else {
                        output.append("<details><summary>\(item.url.lastPathComponent)</summary><dd>")
                        let newData = try getContentsHTML(entryArray: entryArray, parentFolderURL: item.url, showHiddenFiles: showHiddenFiles)
                        output.append(contentsOf: newData.0)
                        directoryCount = directoryCount + newData.1
                        fileCount = fileCount + newData.2
                        output.append("</dd></details>")
                    }
                } else {
                    fileCount += 1
                    output.append("\(item.url.lastPathComponent)<br>")
                }
            }
        }
        return (output, directoryCount, fileCount)
    }
    
    public func getContentsJSON(entryArray: [entry], parentFolderURL: URL, showHiddenFiles: Bool) throws -> ([String], Int, Int) {
        var directoryCount = 0
        var fileCount = 0
        var output: [String] = []
        let folderContents = entryArray.filter { $0.parentURL.path == parentFolderURL.path }
        if !folderContents.isEmpty {
            let lastItemPath = folderContents.last?.url.path
            try folderContents.forEach { item in
                let itemPath = item.url.path
                if item.type == "directory" {
                    directoryCount += 1
                    var contents: [URL] = []
                    if showHiddenFiles {
                        contents = try FileManager.default.contentsOfDirectory(at: item.url, includingPropertiesForKeys: nil)
                    } else {
                        contents = try FileManager.default.contentsOfDirectory(at: item.url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                    }
                    if contents.isEmpty {
                        if itemPath != lastItemPath {
                            output.append("{\"type\":\"\(item.type)\",\"name\":\"\(item.url.lastPathComponent)\"},")
                        } else {
                            output.append("{\"type\":\"\(item.type)\",\"name\":\"\(item.url.lastPathComponent)\"}")
                        }
                    } else {
                        output.append("{\"type\":\"\(item.type)\",\"name\":\"\(item.url.lastPathComponent)\",\"contents\":[")
                        let newData = try getContentsJSON(entryArray: entryArray, parentFolderURL: item.url, showHiddenFiles: showHiddenFiles)
                        output.append(contentsOf: newData.0)
                        directoryCount = directoryCount + newData.1
                        fileCount = fileCount + newData.2
                        if itemPath != lastItemPath {
                            output.append("]},")
                        } else {
                            output.append("]}")
                        }
                    }
                } else {
                    fileCount += 1
                    if itemPath == lastItemPath {
                        output.append("{\"type\":\"\(item.type)\",\"name\":\"\(item.url.lastPathComponent)\"}")
                    } else {
                        output.append("{\"type\":\"\(item.type)\",\"name\":\"\(item.url.lastPathComponent)\"},")
                    }
                }
            }
        }
        return (output, directoryCount, fileCount)
    }
    
    public func getArray(sourceURL: URL, showHiddenFiles: Bool) async -> [entry] {
        if #available(macOS 10.15, *) {
            return await Task {
                var output: [entry] = []
                let items = FileManager.default.enumerator(at: sourceURL, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey, .parentDirectoryURLKey])?.sorted { ($0 as! URL).path < ($1 as! URL).path } as! [URL]
                items.forEach { item in
                    let url = item
                    var type: String = ""
                    if try! item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory! {
                        type = "directory"
                    } else if try! item.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink! {
                        type = "link"
                    } else {
                        type = "file"
                    }
                    let isHidden = try! item.resourceValues(forKeys: [.isHiddenKey]).isHidden!
                    let parentURL = try! item.resourceValues(forKeys: [.parentDirectoryURLKey]).parentDirectory!
                    if !isHidden || showHiddenFiles {
                        output.append(entry(url: url, type: type, parentURL: parentURL, isHidden: isHidden))
                    }
                }
                return output.sorted { $0.url.path < $1.url.path }
            }.value
        } else {
            return []
        }
    }
}
