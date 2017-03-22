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

	TextureCubeImporter::TextureCubeImporter(Context* context, Asset *asset) : AssetImporter(context, asset),
		compressTextures_(false), forceReImport_(false), compressedSizeCubemapFace_(0), compressedSizeFullCubemap_(0)
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

	compressedSizeCubemapFace_ = 0;
	compressedSizeFullCubemap_ = 0;
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
		{
			if (forceReImport_)
			{
				XMLFile* tmpLoadParameters_ = new XMLFile(context_);
				if (tmpLoadParameters_->Load(*file))
				{
					XMLElement textureElem = loadParameters_->GetRoot();
					XMLElement imageElem = textureElem.GetChild("image");

					// Single image and multiple faces with layout
					if (imageElem)
					{
						String name = imageElem.GetAttribute("name");
						
						if (!GetPath(name).Empty())
							fileSystem->Delete(name);
					}
					// Face per image
					else
					{
						XMLElement faceElem = textureElem.GetChild("face");
						while (faceElem)
						{
							String name = faceElem.GetAttribute("name");

							// If path is empty, add the XML file path
							if (!GetPath(name).Empty())
								fileSystem->Delete(name);
						}
					}

					fileSystem->Delete(cachedCubemapPath);
				}
			} 
			else
			{
				return true;
			}
		}

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

			bool saveSucceded = false;
			String imagePath;

			if (compressTextures_)
			{
				float resizefactor;
				float width = image->GetWidth();
				float height = image->GetHeight();

				if (width > compressedSizeFullCubemap_ || height > compressedSizeFullCubemap_)
				{
					if (width >= height)
					{
						resizefactor = compressedSizeFullCubemap_ / width;
					}
					else
					{
						resizefactor = compressedSizeFullCubemap_ / height;
					}

					image->Resize(width*resizefactor, height*resizefactor);
				}

				//Save image as dds
				String imagePath = cachePath + "CUBEMAP/" + asset_->GetGUID() + texName + ".dds";
				if (fileSystem->FileExists(imagePath))
					fileSystem->Delete(imagePath);

				saveSucceded = image->SaveDDS(imagePath);
			} 
			else
			{
				//Save image as png
				imagePath = cachePath + "CUBEMAP/" + asset_->GetGUID() + texName + ".png";
				if (fileSystem->FileExists(imagePath))
					fileSystem->Delete(imagePath);

				saveSucceded = image->SavePNG(imagePath);
			}

			if (saveSucceded)
			{
				//Modify xml node to point to correct image name
				imageElem.SetAttribute("name", imagePath);
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

				bool saveSucceded = false;
				String imagePath;

				if (compressTextures_)
				{
					float resizefactor;
					float width = image->GetWidth();
					float height = image->GetHeight();

					if (width > compressedSizeCubemapFace_ || height > compressedSizeCubemapFace_)
					{
						if (width >= height)
						{
							resizefactor = compressedSizeCubemapFace_ / width;
						}
						else
						{
							resizefactor = compressedSizeCubemapFace_ / height;
						}

						image->Resize(width*resizefactor, height*resizefactor);
					}

					//Save image as dds
					String imagePath = cachePath + "CUBEMAP/" + asset_->GetGUID() + texName + ".dds";
					if (fileSystem->FileExists(imagePath))
						fileSystem->Delete(imagePath);

					saveSucceded = image->SaveDDS(imagePath);
				}
				else
				{
					//Save image as png
					imagePath = cachePath + "CUBEMAP/" + asset_->GetGUID() + texName + ".png";
					if (fileSystem->FileExists(imagePath))
						fileSystem->Delete(imagePath);

					saveSucceded = image->SavePNG(imagePath);
				}

				if (saveSucceded)
				{
					//Modify xml node to point to correct image name
					imageElem.SetAttribute("name", imagePath);
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
		VariantMap tiParameters;
		ImportConfig::ApplyConfig(tiParameters);
		VariantMap::ConstIterator itr = tiParameters.Begin();

		for (; itr != tiParameters.End(); itr++)
		{
			if (itr->first_ == "tiProcess_CompressTextures")
				compressTextures_ = itr->second_.GetBool();
			else if(itr->first_ == "tiProcess_ForceReImport")
				forceReImport_ = itr->second_.GetBool();
		}
    }
}

bool TextureCubeImporter::LoadSettingsInternal(JSONValue& jsonRoot)
{
    if (!AssetImporter::LoadSettingsInternal(jsonRoot))
        return false;

    JSONValue import = jsonRoot.Get("TextureCubeImporter");

    SetDefaults();

	if (import.Get("compressionCubemapFaceSize").IsNumber())
		compressedSizeCubemapFace_ = (CompressedFormat)import.Get("compressionCubemapFaceSize").GetInt();
	
	if (import.Get("compressionFullCubemapSize").IsNumber())
		compressedSizeFullCubemap_ = (CompressedFormat)import.Get("compressionFullCubemapSize").GetInt();

    return true;
}

bool TextureCubeImporter::SaveSettingsInternal(JSONValue& jsonRoot)
{
    if (!AssetImporter::SaveSettingsInternal(jsonRoot))
        return false;

    JSONValue import(JSONValue::emptyObject);
	import.Set("compressionCubemapFaceSize", compressedSizeCubemapFace_);
	import.Set("compressionFullCubemapSize", compressedSizeFullCubemap_);

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
