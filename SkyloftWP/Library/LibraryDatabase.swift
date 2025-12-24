//
//  LibraryDatabase.swift
//  SkyloftWP
//
//  SQLite database for video library management
//

import Foundation
import SQLite3

class LibraryDatabase {
    
    // MARK: - Singleton
    
    static let shared = LibraryDatabase()
    
    // MARK: - Properties
    
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.midtv.database", qos: .userInitiated)
    
    private var databasePath: String {
        let path = ConfigurationManager.shared.config.library.path
        return (path as NSString).appendingPathComponent("library.sqlite")
    }
    
    // MARK: - Initialization
    
    private init() {
        dbQueue.sync {
            openDatabase()
            createTables()
        }
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Connection
    
    private func openDatabase() {
        let path = databasePath
        
        // Ensure directory exists
        let directory = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        
        // SQLITE_OPEN_FULLMUTEX for thread safety
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            print("Failed to open database at: \(path)")
            return
        }
        
        // Enable WAL mode for better concurrency
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        
        print("Database opened at: \(path)")
    }
    
    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    private func createTables() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS videos (
            id TEXT PRIMARY KEY,
            source_url TEXT,
            prompt TEXT,
            author TEXT,
            midjourney_job_id TEXT,
            saved_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            duration REAL,
            resolution TEXT,
            file_size INTEGER,
            local_path TEXT NOT NULL,
            thumbnail_path TEXT,
            favorite INTEGER DEFAULT 0,
            play_count INTEGER DEFAULT 0,
            last_played DATETIME
        );
        
        CREATE INDEX IF NOT EXISTS idx_saved_at ON videos(saved_at DESC);
        CREATE INDEX IF NOT EXISTS idx_favorite ON videos(favorite);
        CREATE INDEX IF NOT EXISTS idx_author ON videos(author);
        """
        
        var errorMessage: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, createTableSQL, nil, nil, &errorMessage) != SQLITE_OK {
            if let error = errorMessage {
                print("Failed to create tables: \(String(cString: error))")
                sqlite3_free(errorMessage)
            }
        }
    }
    
    // MARK: - CRUD Operations
    
    func insert(_ video: VideoItem) -> Bool {
        return dbQueue.sync {
            let insertSQL = """
            INSERT OR REPLACE INTO videos (
                id, source_url, prompt, author, midjourney_job_id,
                saved_at, duration, resolution, file_size,
                local_path, thumbnail_path, favorite, play_count, last_played
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
                print("Failed to prepare insert statement")
                return false
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_text(statement, 1, video.id, -1, SQLITE_TRANSIENT)
            bindOptionalText(statement, 2, video.sourceUrl)
            bindOptionalText(statement, 3, video.prompt)
            bindOptionalText(statement, 4, video.author)
            bindOptionalText(statement, 5, video.midjourneyJobId)
            sqlite3_bind_double(statement, 6, video.savedAt.timeIntervalSince1970)
            bindOptionalDouble(statement, 7, video.duration)
            bindOptionalText(statement, 8, video.resolution)
            bindOptionalInt64(statement, 9, video.fileSize)
            sqlite3_bind_text(statement, 10, video.localPath, -1, SQLITE_TRANSIENT)
            bindOptionalText(statement, 11, video.thumbnailPath)
            sqlite3_bind_int(statement, 12, video.favorite ? 1 : 0)
            sqlite3_bind_int(statement, 13, Int32(video.playCount))
            bindOptionalDouble(statement, 14, video.lastPlayed?.timeIntervalSince1970)
            
            return sqlite3_step(statement) == SQLITE_DONE
        }
    }
    
    func fetchAll() -> [VideoItem] {
        return dbQueue.sync {
            // 오래된 순으로 정렬 - 새 영상이 뒤에 추가되어 인덱스 밀림 방지
            let query = "SELECT * FROM videos ORDER BY saved_at ASC;"
            return executeQuery(query)
        }
    }
    
    func fetch(id: String) -> VideoItem? {
        let query = "SELECT * FROM videos WHERE id = ?;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, id, -1, SQLITE_TRANSIENT)
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return videoFromStatement(statement)
        }
        
        return nil
    }
    
    func fetchFavorites() -> [VideoItem] {
        let query = "SELECT * FROM videos WHERE favorite = 1 ORDER BY saved_at DESC;"
        return executeQuery(query)
    }
    
    func search(query: String) -> [VideoItem] {
        let searchSQL = """
        SELECT * FROM videos 
        WHERE prompt LIKE ? OR author LIKE ? OR local_path LIKE ?
        ORDER BY saved_at DESC;
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, searchSQL, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        
        defer { sqlite3_finalize(statement) }
        
        let searchPattern = "%\(query)%"
        sqlite3_bind_text(statement, 1, searchPattern, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, searchPattern, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, searchPattern, -1, SQLITE_TRANSIENT)
        
        var videos: [VideoItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let video = videoFromStatement(statement) {
                videos.append(video)
            }
        }
        
        return videos
    }
    
    func update(_ video: VideoItem) -> Bool {
        return insert(video)  // INSERT OR REPLACE handles updates
    }
    
    func delete(id: String) -> Bool {
        return dbQueue.sync {
            let deleteSQL = "DELETE FROM videos WHERE id = ?;"
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
                return false
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_text(statement, 1, id, -1, SQLITE_TRANSIENT)
            
            return sqlite3_step(statement) == SQLITE_DONE
        }
    }
    
    func updatePlayCount(id: String) {
        let updateSQL = """
        UPDATE videos 
        SET play_count = play_count + 1, last_played = ?
        WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
        sqlite3_bind_text(statement, 2, id, -1, SQLITE_TRANSIENT)
        
        sqlite3_step(statement)
    }
    
    func toggleFavorite(id: String) -> Bool {
        let updateSQL = "UPDATE videos SET favorite = NOT favorite WHERE id = ?;"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, id, -1, SQLITE_TRANSIENT)
        
        return sqlite3_step(statement) == SQLITE_DONE
    }
    
    /// Update video metadata after background processing
    func updateMetadata(id: String, duration: Double, resolution: String, thumbnailPath: String?) {
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            
            let updateSQL = """
            UPDATE videos 
            SET duration = ?, resolution = ?, thumbnail_path = ?
            WHERE id = ?;
            """
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
                print("Failed to prepare updateMetadata statement")
                return
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_double(statement, 1, duration)
            sqlite3_bind_text(statement, 2, resolution, -1, self.SQLITE_TRANSIENT)
            self.bindOptionalText(statement, 3, thumbnailPath)
            sqlite3_bind_text(statement, 4, id, -1, self.SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ [DB] Updated metadata for: \(id)")
            } else {
                print("❌ [DB] Failed to update metadata for: \(id)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func executeQuery(_ query: String) -> [VideoItem] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        
        defer { sqlite3_finalize(statement) }
        
        var videos: [VideoItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let video = videoFromStatement(statement) {
                videos.append(video)
            }
        }
        
        return videos
    }
    
    private func videoFromStatement(_ statement: OpaquePointer?) -> VideoItem? {
        guard let statement = statement else { return nil }
        
        let id = String(cString: sqlite3_column_text(statement, 0))
        let sourceUrl = columnText(statement, 1)
        let prompt = columnText(statement, 2)
        let author = columnText(statement, 3)
        let midjourneyJobId = columnText(statement, 4)
        let savedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
        let duration = columnDouble(statement, 6)
        let resolution = columnText(statement, 7)
        let fileSize = columnInt64(statement, 8)
        let localPath = String(cString: sqlite3_column_text(statement, 9))
        let thumbnailPath = columnText(statement, 10)
        let favorite = sqlite3_column_int(statement, 11) == 1
        let playCount = Int(sqlite3_column_int(statement, 12))
        let lastPlayed = columnDouble(statement, 13).map { Date(timeIntervalSince1970: $0) }
        
        return VideoItem(
            id: id,
            sourceUrl: sourceUrl,
            prompt: prompt,
            author: author,
            midjourneyJobId: midjourneyJobId,
            savedAt: savedAt,
            duration: duration,
            resolution: resolution,
            fileSize: fileSize,
            localPath: localPath,
            thumbnailPath: thumbnailPath,
            favorite: favorite,
            playCount: playCount,
            lastPlayed: lastPlayed
        )
    }
    
    // MARK: - SQLite Binding Helpers
    
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    private func bindOptionalText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value = value {
            sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
    
    private func bindOptionalDouble(_ statement: OpaquePointer?, _ index: Int32, _ value: Double?) {
        if let value = value {
            sqlite3_bind_double(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
    
    private func bindOptionalInt64(_ statement: OpaquePointer?, _ index: Int32, _ value: Int64?) {
        if let value = value {
            sqlite3_bind_int64(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
    
    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }
    
    private func columnDouble(_ statement: OpaquePointer?, _ index: Int32) -> Double? {
        if sqlite3_column_type(statement, index) == SQLITE_NULL {
            return nil
        }
        return sqlite3_column_double(statement, index)
    }
    
    private func columnInt64(_ statement: OpaquePointer?, _ index: Int32) -> Int64? {
        if sqlite3_column_type(statement, index) == SQLITE_NULL {
            return nil
        }
        return sqlite3_column_int64(statement, index)
    }
}

