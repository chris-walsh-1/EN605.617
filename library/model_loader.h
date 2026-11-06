#pragma once
 
#include <assimp/Importer.hpp>
#include <assimp/postprocess.h>
#include <assimp/scene.h>
 
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>
#include "vector_math.h"
 
struct MeshData {
    std::vector<Vec3>     vertices;  // one entry per unique vertex
    std::vector<uint32_t> indices;   // 3 indices per triangle
 
    size_t numTriangles() const { return indices.size() / 3; }

    float* verticesToArray() const {
        float* arr = new float[vertices.size() * 3];
        for (size_t i = 0; i < vertices.size(); ++i) {
            arr[i * 3 + 0] = vertices[i].x;
            arr[i * 3 + 1] = vertices[i].y;
            arr[i * 3 + 2] = vertices[i].z;
        }
        return arr;
    }
};
 
// Loads every mesh in the file and merges them into a single MeshData.
// Node transforms are baked into the vertices (aiProcess_PreTransformVertices),
// so the result is in one common coordinate space.
// Returns true on success; on failure `out` is left empty and an error is printed.
inline bool loadModel(const std::string& path, MeshData& out)
{
    out = MeshData{};
 
    Assimp::Importer importer;
 
    // Drop points and lines; we only care about triangles.
    importer.SetPropertyInteger(AI_CONFIG_PP_SBP_REMOVE,
                                aiPrimitiveType_POINT | aiPrimitiveType_LINE);
 
    const unsigned int flags =
        aiProcess_Triangulate            |  // quads/polygons -> triangles
        aiProcess_JoinIdenticalVertices  |  // build a proper indexed mesh
        aiProcess_PreTransformVertices   |  // flatten node hierarchy, apply transforms
        aiProcess_SortByPType            |  // needed for the point/line removal above
        aiProcess_ValidateDataStructure;
 
    const aiScene* scene = importer.ReadFile(path, flags);
 
    if (!scene || (scene->mFlags & AI_SCENE_FLAGS_INCOMPLETE) || !scene->mRootNode) {
        std::cerr << "Assimp failed to load '" << path << "': "
                  << importer.GetErrorString() << "\n";
        return false;
    }
    if (scene->mNumMeshes == 0) {
        std::cerr << "'" << path << "' contains no meshes\n";
        return false;
    }
 
    // Reserve up front.
    size_t totalVerts = 0, totalIdx = 0;
    for (unsigned m = 0; m < scene->mNumMeshes; ++m) {
        totalVerts += scene->mMeshes[m]->mNumVertices;
        totalIdx   += static_cast<size_t>(scene->mMeshes[m]->mNumFaces) * 3;
    }
    out.vertices.reserve(totalVerts);
    out.indices.reserve(totalIdx);
    
    for (unsigned m = 0; m < scene->mNumMeshes; ++m) {
        const aiMesh* mesh = scene->mMeshes[m];
        const uint32_t baseVertex = static_cast<uint32_t>(out.vertices.size());

        for (unsigned v = 0; v < mesh->mNumVertices; ++v) {
            const aiVector3D& p = mesh->mVertices[v];
            out.vertices.push_back({p.x, p.y, p.z});
        }
 
        for (unsigned f = 0; f < mesh->mNumFaces; ++f) {
            const aiFace& face = mesh->mFaces[f];
            if (face.mNumIndices != 3) continue;  // safety; shouldn't happen after Triangulate
            out.indices.push_back(baseVertex + face.mIndices[0]);
            out.indices.push_back(baseVertex + face.mIndices[1]);
            out.indices.push_back(baseVertex + face.mIndices[2]);
        }
    }
 
    std::cout << "Loaded '" << path << "': "
              << out.vertices.size() << " vertices, "
              << out.indices.size() << " indices, "
              << out.numTriangles() << " triangles\n";
    return !out.indices.empty();
}
 