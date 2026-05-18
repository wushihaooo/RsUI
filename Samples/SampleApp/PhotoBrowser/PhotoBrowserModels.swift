import Foundation
import UWP
import WinUI

struct SamplePhoto: Identifiable, Hashable {
    let id: String
    let title: String
    let albumID: String
    let albumTitle: String
    let location: String
    let date: String
    let camera: String
    let dimensions: String
    let fileSize: String
    let accent: UWP.Color
    let secondary: UWP.Color
    let sourceURL: URL?
}

struct PhotoAlbumSummary: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
}

struct ImportedPhotoAlbum: Identifiable, Hashable {
    let id: String
    let path: String
    let title: String
    let photos: [SamplePhoto]

    var summary: String {
        if photos.isEmpty {
            return "No supported image files were found in this folder."
        }
        return "\(photos.count) local image\(photos.count == 1 ? "" : "s") imported from \(path)"
    }
}

enum PhotoBrowserRoutes {
    static let host = "photos"

    static var home: URL { URL(string: "rs://photos/home")! }
    static var library: URL { URL(string: "rs://photos/library")! }
    static var importFolder: URL { URL(string: "rs://photos/import")! }

    static func album(_ id: String) -> URL {
        URL(string: "rs://photos/album/\(id)")!
    }

    static func photo(_ id: String) -> URL {
        URL(string: "rs://photos/photo/\(id)")!
    }

}
