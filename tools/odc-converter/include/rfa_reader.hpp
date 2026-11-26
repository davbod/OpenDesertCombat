#pragma once

#include <string>
#include <vector>
#include <cstdint>
#include <filesystem>

namespace odc {

struct RfaEntry {
    std::string path;
    uint32_t offset = 0;
    uint32_t compressed_size = 0;
    uint32_t uncompressed_size = 0;
    bool is_compressed = false;
};

class RfaReader {
public:
    RfaReader() = default;
    ~RfaReader() = default;

    bool Open(const std::filesystem::path& rfa_path);
    const std::vector<RfaEntry>& GetEntries() const { return entries_; }
    bool ExtractAll(const std::filesystem::path& destination_dir);
    bool ExtractFile(const RfaEntry& entry, const std::filesystem::path& dest_path);

private:
    std::filesystem::path file_path_;
    std::vector<RfaEntry> entries_;
};

} // namespace odc
