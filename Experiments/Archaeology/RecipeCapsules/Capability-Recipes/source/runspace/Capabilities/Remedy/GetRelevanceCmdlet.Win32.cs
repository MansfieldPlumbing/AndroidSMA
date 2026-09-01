using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Management.Automation;
using Microsoft.Data.Sqlite;
using Subsystem.Cm;

namespace Subsystem.Capabilities.Remedy;

[Cmdlet(VerbsCommon.Get, "Relevance")]
public class GetRelevanceCmdlet : PSCmdlet
{
    protected override void ProcessRecord()
    {
        // 1. Find project root
        string root = GetProjectRoot();
        var blockedDirs = new[] { "node_modules", "bin", "obj", "dist", "build", ".git", ".vs", "packages", "vendor", "tmp" };
        var whitelist = new[] { ".cs", ".ps1", ".js", ".ts", ".html", ".css", ".json", ".csproj", ".xml", ".md" };
        
        var recentFiles = new List<FileInfo>();
        var stack = new Stack<string>();
        stack.Push(root);
        
        while (stack.Count > 0)
        {
            var current = stack.Pop();
            string name = Path.GetFileName(current);
            if (blockedDirs.Any(d => name.Equals(d, StringComparison.OrdinalIgnoreCase))) continue;
            
            try
            {
                foreach (var file in Directory.GetFiles(current))
                {
                    string ext = Path.GetExtension(file).ToLowerInvariant();
                    if (whitelist.Contains(ext))
                    {
                        recentFiles.Add(new FileInfo(file));
                    }
                }
                foreach (var dir in Directory.GetDirectories(current))
                {
                    stack.Push(dir);
                }
            }
            catch {}
        }
        
        var sortedFiles = recentFiles
            .OrderByDescending(f => f.LastWriteTimeUtc)
            .Take(5)
            .Select(f => new
            {
                File = Path.GetRelativePath(root, f.FullName).Replace('\\', '/'),
                LastModified = f.LastWriteTimeUtc.ToLocalTime().ToString("g")
            })
            .ToList();

        // 2. Query open requests
        var openRequests = new List<object>();
        try
        {
            var requests = RequestHive.Query(null, null, "Open", null, null, 0, 0);
            foreach (var r in requests.Take(5))
            {
                openRequests.Add(new
                {
                    Id = r.Id,
                    Kind = r.Kind.ToString(),
                    Category = r.Category,
                    Summary = r.Summary
                });
            }
        }
        catch {}

        // 3. Query last 3 EOS logs
        var recentEos = new List<object>();
        try
        {
            string dbPath = RequestHive.HivePath;
            if (File.Exists(dbPath))
            {
                using var conn = new SqliteConnection($"Data Source={dbPath}");
                conn.Open();
                using var cmd = conn.CreateCommand();
                cmd.CommandText = @"
                    SELECT e.request, r.summary, e.disposition, e.body, e.noted 
                    FROM EosLog e 
                    LEFT JOIN Requests r ON e.request = r.id 
                    ORDER BY e.noted DESC 
                    LIMIT 3;";
                using var reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    recentEos.Add(new
                    {
                        RequestId = reader.GetInt64(0),
                        RequestSummary = reader.IsDBNull(1) ? "" : reader.GetString(1),
                        Disposition = reader.GetString(2),
                        Body = reader.GetString(3),
                        Time = DateTimeOffset.FromUnixTimeSeconds(reader.GetInt64(4)).ToLocalTime().ToString("g")
                    });
                }
            }
        }
        catch {}

        WriteObject(new
        {
            RecentModifiedFiles = sortedFiles,
            ActiveRequests = openRequests,
            RecentEosLogs = recentEos
        });
    }

    private static string GetProjectRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null)
        {
            if (Directory.Exists(Path.Combine(dir.FullName, ".git")))
            {
                return dir.FullName;
            }
            if (File.Exists(Path.Combine(dir.FullName, "subsystem-registry.db")) || 
                File.Exists(Path.Combine(dir.FullName, "subsystem-requests.db")))
            {
                return dir.FullName;
            }
            dir = dir.Parent;
        }
        return AppContext.BaseDirectory;
    }
}
