//
// Copyright (c) 2014-2016 THUNDERBEAST GAMES LLC
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#include <Atomic/Resource/ResourceCache.h>
#include <Atomic/Resource/Image.h>
#include "Atomic/Resource/XMLFile.h"
#include <Atomic/Atomic2D/Sprite2D.h>
#include <Atomic/Atomic2D/StaticSprite2D.h>
#include <Atomic/IO/FileSystem.h>

#include <ToolCore/Import/ImportConfig.h>
#include <Atomic/Graphics/Renderer.h>

#include "Asset.h"
#include "AssetDatabase.h"
#include "TextureCubeImporter.h"


namespace ToolCore
{

	TextureCubeImporter::TextureCubeImporter(Context* context, Asset *asset) : AssetImporter(context, asset)
{
    requiresCacheFile_ = true;

    ApplyProjectImportConfig();
}

	TextureCubeImporter::~TextureCubeImporter()
{

}

void TextureCubeImporter::SetDefaults()
{
    AssetImporter::SetDefaults();
}

bool TextureCubeImporter::Import()
{
	String relativePath = asset_->GetRelativePath();

	if (!GetExtension(relativePath).Compare(".cubemap", true))
	{
		AssetDatabase* db = GetSubsystem<AssetDatabase>();
		ResourceCache* cache = GetSubsystem<ResourceCache>();

		SharedPtr<File> file = cache->GetFile(relativePath);
		if (!file)
			return false;

		String cachePath = db->GetCachePath();

		FileSystem* fileSystem = GetSubsystem<FileSystem>();

		String cachedCubemapPath = cachePath + "CUBEMAP/" + asset_->GetGUID() + ".cubemap";
		
		if (fileSystem->FileExists(cachedCubemapPath))
			fileSystem->Delete(cachedCubemapPath);

		fileSystem->CreateDirs(cachePath, "CUBEMAP/");

		String cubemapPath, cubemapName, cubemapExt;
		SplitPath(relativePath, cubemapPath, cubemapName, cubemapExt);

		loadParameters_ = new XMLFile(context_);
		if (!loadParameters_->Load(*file))
		{
			loadParameters_.Reset();
			return false;
		}

		XMLElement textureElem = loadParameters_->GetRoot();
		XMLElement imageElem = textureElem.GetChild("image");

		// Single image and multiple faces with layout
		if (imageElem)
		{
			String name = imageElem.GetAttribute("name");
			// If path is empty, add the XML file path
			if (GetPath(name).Empty())
				name = cubemapPath + name;

			String texPath, texName, texExt;
			SplitPath(name, texPath, texName, texExt);

			SharedPtr<Image> image = cache->GetTempResource<Image>(name);
			if (!image)
				return false;

			//Save image as dds
			String compressedPath = cachePath + "CUBEMAP/" + asset_->GetGUID() + texName + ".dds";
			if (fileSystem->FileExists(compressedPath))
				fileSystem->Delete(compressedPath);

			if (image->SaveDDS(compressedPath))
			{
				//Modify xml node to point to correct image name
				imageElem.SetAttribute("name", compressedPath);
			}
		}
		// Face per image
		else
		{
			XMLElement faceElem = textureElem.GetChild("face");
			while (faceElem)
			{
				String name = faceElem.GetAttribute("name");

				// If path is empty, add the XML file path
				if (GetPath(name).Empty())
					name = cubemapPath + name;

				String texPath, texName, texExt;
				SplitPath(name, texPath, texName, texExt);

				SharedPtr<Image> image = cache->GetTempResource<Image>(name);
				if (!image)
					continue;

				//Save image as dds
				String compressedPath = cachePath + "CUBEMAP/" + asset_->GetGUID() + texName + ".dds";
				if (fileSystem->FileExists(compressedPath))
					fileSystem->Delete(compressedPath);

				if (image->SaveDDS(compressedPath))
				{
					//Modify xml node to point to correct image name
					faceElem.SetAttribute("name", compressedPath);
				}

				faceElem = faceElem.GetNext("face");
			}
		}

		//Save new .cubemap pointing to dds compressed faces
		File xmlFile(context_, cachedCubemapPath, FILE_WRITE);
		loadParameters_->Save(xmlFile);
	}

    return true;
}

void TextureCubeImporter::ApplyProjectImportConfig()
{
    if (ImportConfig::IsLoaded())
    {
    }
}

bool TextureCubeImporter::LoadSettingsInternal(JSONValue& jsonRoot)
{
    if (!AssetImporter::LoadSettingsInternal(jsonRoot))
        return false;

    JSONValue import = jsonRoot.Get("TextureCubeImporter");

    SetDefaults();

    return true;
}

bool TextureCubeImporter::SaveSettingsInternal(JSONValue& jsonRoot)
{
    if (!AssetImporter::SaveSettingsInternal(jsonRoot))
        return false;

    JSONValue import(JSONValue::emptyObject);

    jsonRoot.Set("TextureCubeImporter", import);

    return true;
}

Resource* TextureCubeImporter::GetResource(const String& typeName)
{
    if (!typeName.Length())
        return 0;

    ResourceCache* cache = GetSubsystem<ResourceCache>();
    return cache->GetResource(typeName, asset_->GetPath());

}

}
