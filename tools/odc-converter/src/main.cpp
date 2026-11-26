#include <iostream>
#include <string_view>
#include "rfa_reader.hpp"

void PrintUsage() {
    std::cout << "OpenDesertCombat Asset Converter (odc-converter)\n"
              << "Usage: odc-converter <command> [options]\n\n"
              << "Commands:\n"
              << "  unpack <archive.rfa> <out_dir>     Extract Refractor .rfa archive\n"
              << "  mesh2gltf <mesh.sm> <out.glb>      Convert Refractor .sm mesh to glTF 2.0\n"
              << "  parse-con <script.con>             Parse BF1942/DC console script to JSON\n";
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        PrintUsage();
        return 1;
    }

    std::string_view command = argv[1];

    if (command == "unpack") {
        if (argc < 4) {
            std::cerr << "Error: unpack requires <archive.rfa> and <out_dir>\n";
            return 1;
        }
        odc::RfaReader reader;
        if (!reader.Open(argv[2])) {
            return 1;
        }
        return reader.ExtractAll(argv[3]) ? 0 : 1;
    } else if (command == "mesh2gltf") {
        std::cout << "Converting .sm mesh to glTF...\n";
        // To be implemented in next step
        return 0;
    } else if (command == "parse-con") {
        std::cout << "Parsing .con script...\n";
        // To be implemented in next step
        return 0;
    } else {
        std::cerr << "Unknown command: " << command << "\n";
        PrintUsage();
        return 1;
    }
}
