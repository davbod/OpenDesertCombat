# Refractor 1 `.rfa` File Format

> [!NOTE] Legacy research notes, kept for reference only. The game does not read these
> formats, and the [original-content policy](../design_goals.md) rules out using assets or
> data from *Battlefield 1942* or *Desert Combat*. These notes and `tools/odc-converter`
> are scheduled for removal from this repository before going public (see
> [roadmap C0](../roadmap.md#c0--before-going-public)).

The `.rfa` (Refractor Archive) format is used by *Battlefield 1942* and mods like *Desert Combat* to package maps, animations, sounds, meshes, and scripts.

## Structure

1. **Header**:
   - Signature / Magic bytes (`RefPack` or compressed block indicator, or uncompressed dictionary at EOF depending on version).
2. **File Entries / Index Table**:
   - Path string
   - Compressed size / uncompressed size
   - Offset in archive
   - Flags (compression type, usually LZO or uncompressed)
3. **Data Blocks**:
   - Stream of raw or LZO-compressed file payloads.

---

# Refractor 1 StandardMesh (`.sm`) Format

Used for vehicles, buildings, weapons, and static props.

## Structure
- **Header**: Version identifier (typically version 10/11)
- **Materials**: Material count, shader names, texture map names (`.dds`)
- **LOD Blocks**: Level of detail meshes
- **Vertices**: Positions `(x, y, z)`, Normals `(nx, ny, nz)`, UV Coordinates `(u, v)`
- **Indices**: Triangles index list
- **Weights / Bones**: For animated objects (or `.ske` / `.baf` for skinned soldiers)
