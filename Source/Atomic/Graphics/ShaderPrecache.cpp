//
// Copyright (c) 2008-2017 the Urho3D project.
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

#include "../Precompiled.h"

#include "../Graphics/Graphics.h"
#include "../Graphics/GraphicsImpl.h"
#include "../Graphics/ShaderPrecache.h"
#include "../Graphics/ShaderVariation.h"
#include "../IO/File.h"
#include "../IO/FileSystem.h"
#include "../IO/Log.h"

#include "../DebugNew.h"

namespace Atomic
{

ShaderPrecache::ShaderPrecache(Context* context, const String& fileName) :
    Object(context),
    fileName_(fileName),
    xmlFile_(context)
{
    if (GetSubsystem<FileSystem>()->FileExists(fileName))
    {
        // If file exists, read the already listed combinations
        File source(context_, fileName);
        xmlFile_.Load(source);

        XMLElement shader = xmlFile_.GetRoot().GetChild("shader");
        while (shader)
        {
            String oldCombination;

            for (int i = 0; i < ShaderType::MAX_SHADER_TYPE; i++)
            {
                String shaderName = shader.GetAttribute(ShaderTypeName[i]);
                String shaderDefineName = shader.GetAttribute(ShaderTypeDefineName[i]);
                
                if (!shaderName.Empty() && !shaderDefineName.Empty())
                {
                    oldCombination += shaderName + " " + shaderDefineName;

                    if (i != ShaderType::MAX_SHADER_TYPE - 1)
                    {
                        oldCombination += " ";
                    }
                }  
            }

            usedCombinations_.Insert(oldCombination);

            shader = shader.GetNext("shader");
        }
    }

    // If no file yet or loading failed, create the root element now
    if (!xmlFile_.GetRoot())
        xmlFile_.CreateRoot("shaders");

    ATOMIC_LOGINFO("Begin dumping shaders to " + fileName_);
}

ShaderPrecache::~ShaderPrecache()
{
    ATOMIC_LOGINFO("End dumping shaders");

    if (usedCombinations_.Empty())
        return;

    File dest(context_, fileName_, FILE_WRITE);
    xmlFile_.Save(dest);
}

void ShaderPrecache::StoreShaders(ShaderVariation* vs
    , ShaderVariation* ps
    , ShaderVariation* gs /* = nullptr*/
    , ShaderVariation* hs /* = nullptr*/
    , ShaderVariation* ds /* = nullptr*/
    , ShaderVariation* cs /* = nullptr*/
    )
{
    // We are storing shader variation so we need to store a valid set

    // vs needs to always exist
    // gs is optional but require vs and ps
    // ds //hs are optional but set is required to have both and vs/ps
    // cs exist on its own

    // Check for duplicate using pointers first (fast)

    SharedArrayPtr<ShaderVariation*> shaderSet(new ShaderVariation*[MAX_SHADER_PARAMETER_GROUPS]);

    shaderSet[ShaderType::VS] = vs;
    shaderSet[ShaderType::PS] = ps;
    shaderSet[ShaderType::GS] = gs;
    shaderSet[ShaderType::HS] = hs;
    shaderSet[ShaderType::DS] = ds;
    shaderSet[ShaderType::CS] = cs;

    if (usedPtrCombinations_.Contains(shaderSet))
        return;
    usedPtrCombinations_.Insert(shaderSet);

    String vsName;
    String psName;
    String gsName;
    String hsName;
    String dsName;
    String csName;

    String newCombination;

    if (vs && ps && gs && hs && ds)
    {
        vsName = vs->GetName();
        psName = ps->GetName();
        gsName = gs->GetName();
        hsName = hs->GetName();
        dsName = ds->GetName();

        const String& vsDefines = vs->GetDefines();
        const String& psDefines = ps->GetDefines();
        const String& gsDefines = gs->GetDefines();
        const String& hsDefines = hs->GetDefines();
        const String& dsDefines = ds->GetDefines();

        // Check for duplicate using strings (needed for combinations loaded from existing file)
        newCombination = vsName + " " + vsDefines 
            + " " + psName + " " + psDefines
            + " " + gsName + " " + gsDefines
            + " " + hsName + " " + hsDefines
            + " " + dsName + " " + dsDefines;

        if (usedCombinations_.Contains(newCombination))
            return;

        usedCombinations_.Insert(newCombination);

        XMLElement shaderElem = xmlFile_.GetRoot().CreateChild("shader");
        shaderElem.SetAttribute(ShaderTypeName[ShaderType::VS], vsName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::VS], vsDefines);

        shaderElem.SetAttribute(ShaderTypeName[ShaderType::PS], psName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::PS], psDefines);

        shaderElem.SetAttribute(ShaderTypeName[ShaderType::GS], gsName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::GS], gsDefines);

        shaderElem.SetAttribute(ShaderTypeName[ShaderType::HS], hsName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::HS], hsDefines);

        shaderElem.SetAttribute(ShaderTypeName[ShaderType::DS], dsName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::DS], dsDefines);
    }
    else if (vs && ps && gs)
    {
        vsName = vs->GetName();
        psName = ps->GetName();
        gsName = gs->GetName();

        const String& vsDefines = vs->GetDefines();
        const String& psDefines = ps->GetDefines();
        const String& gsDefines = gs->GetDefines();

        // Check for duplicate using strings (needed for combinations loaded from existing file)
        newCombination = vsName + " " + vsDefines
            + " " + psName + " " + psDefines
            +" " + gsName + " " + gsDefines;

        if (usedCombinations_.Contains(newCombination))
            return;

        usedCombinations_.Insert(newCombination);

        XMLElement shaderElem = xmlFile_.GetRoot().CreateChild("shader");
        shaderElem.SetAttribute(ShaderTypeName[ShaderType::VS], vsName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::VS], vsDefines);

        shaderElem.SetAttribute(ShaderTypeName[ShaderType::PS], psName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::PS], psDefines);

        shaderElem.SetAttribute(ShaderTypeName[ShaderType::GS], gsName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::GS], gsDefines);
    }
    else if (vs && ps && hs && ds)
    {
        vsName = vs->GetName();
        psName = ps->GetName();
        hsName = hs->GetName();
        dsName = ds->GetName();

        const String& vsDefines = vs->GetDefines();
        const String& psDefines = ps->GetDefines();
        const String& hsDefines = hs->GetDefines();
        const String& dsDefines = ds->GetDefines();

        // Check for duplicate using strings (needed for combinations loaded from existing file)
        newCombination = vsName + " " + vsDefines
            + " " + psName + " " + psDefines
            + " " + hsName + " " + hsDefines
            + " " + dsName + " " + dsDefines;

        if (usedCombinations_.Contains(newCombination))
            return;

        usedCombinations_.Insert(newCombination);

        XMLElement shaderElem = xmlFile_.GetRoot().CreateChild("shader");
        shaderElem.SetAttribute(ShaderTypeName[ShaderType::VS], vsName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::VS], vsDefines);

        shaderElem.SetAttribute(ShaderTypeName[ShaderType::PS], psName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::PS], psDefines);

        shaderElem.SetAttribute(ShaderTypeName[ShaderType::HS], hsName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::HS], hsDefines);

        shaderElem.SetAttribute(ShaderTypeName[ShaderType::DS], dsName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::DS], dsDefines);
    }
    else if (vs && ps)
    {
        vsName = vs->GetName();
        psName = ps->GetName();

        const String& vsDefines = vs->GetDefines();
        const String& psDefines = ps->GetDefines();

        // Check for duplicate using strings (needed for combinations loaded from existing file)
        newCombination = vsName + " " + vsDefines + " " + psName + " " + psDefines;

        if (usedCombinations_.Contains(newCombination))
            return;

        usedCombinations_.Insert(newCombination);

        XMLElement shaderElem = xmlFile_.GetRoot().CreateChild("shader");
        shaderElem.SetAttribute(ShaderTypeName[ShaderType::VS], vsName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::VS], vsDefines);

        shaderElem.SetAttribute(ShaderTypeName[ShaderType::PS], psName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::PS], psDefines);
    }
    else if (cs)
    {
        csName = cs->GetName();
        const String& csDefines = cs->GetDefines();

        // Check for duplicate using strings (needed for combinations loaded from existing file)
        newCombination = csName + " " + csDefines;

        if (usedCombinations_.Contains(newCombination))
            return;

        usedCombinations_.Insert(newCombination);

        XMLElement shaderElem = xmlFile_.GetRoot().CreateChild("shader");
        shaderElem.SetAttribute(ShaderTypeName[ShaderType::CS], csName);
        shaderElem.SetAttribute(ShaderTypeDefineName[ShaderType::CS], csDefines);
    }
    else
    {
        return;
    }
}

void ShaderPrecache::LoadShaders(Graphics* graphics, Deserializer& source)
{
    ATOMIC_LOGDEBUG("Begin precaching shaders");

    XMLFile xmlFile(graphics->GetContext());
    xmlFile.Load(source);

    XMLElement shader = xmlFile.GetRoot().GetChild("shader");
    while (shader)
    {
        String vsDefines = shader.GetAttribute(ShaderTypeDefineName[ShaderType::VS]);
        String psDefines = shader.GetAttribute(ShaderTypeDefineName[ShaderType::PS]);
        String gsDefines = shader.GetAttribute(ShaderTypeDefineName[ShaderType::GS]);
        String hsDefines = shader.GetAttribute(ShaderTypeDefineName[ShaderType::HS]);
        String dsDefines = shader.GetAttribute(ShaderTypeDefineName[ShaderType::DS]);
        String csDefines = shader.GetAttribute(ShaderTypeDefineName[ShaderType::CS]);

        String vsName = shader.GetAttribute(ShaderTypeName[ShaderType::VS]);
        String psName = shader.GetAttribute(ShaderTypeName[ShaderType::PS]);
        String gsName = shader.GetAttribute(ShaderTypeName[ShaderType::GS]);
        String hsName = shader.GetAttribute(ShaderTypeName[ShaderType::HS]);
        String dsName = shader.GetAttribute(ShaderTypeName[ShaderType::DS]);
        String csName = shader.GetAttribute(ShaderTypeName[ShaderType::CS]);

        // Check for illegal variations on OpenGL ES and skip them
        // gs / hs / ds / cs not valid
#ifdef GL_ES_VERSION_2_0
        if (
            !gsName.Empty() ||
            !hsName.Empty() ||
            !dsName.Empty() ||
            !csName.Empty() ||
#ifndef __EMSCRIPTEN__
            vsDefines.Contains("INSTANCED") ||
#endif
            (psDefines.Contains("POINTLIGHT") && psDefines.Contains("SHADOW")))
        {
            shader = shader.GetNext("shader");
            continue;
        }
#endif

        ShaderVariation* vs = graphics->GetShader(ShaderType::VS, vsName, vsDefines);
        ShaderVariation* ps = graphics->GetShader(ShaderType::PS, psName, psDefines);
        ShaderVariation* gs = graphics->GetShader(ShaderType::GS, gsName, gsDefines);
        ShaderVariation* hs = graphics->GetShader(ShaderType::HS, hsName, hsDefines);
        ShaderVariation* ds = graphics->GetShader(ShaderType::DS, dsName, dsDefines);
        ShaderVariation* cs = graphics->GetShader(ShaderType::CS, csName, csDefines);

        // Set the shaders active to actually compile them
        // This step should take care of checking if the set is valid
        graphics->SetShaders(vs, ps, gs, hs, ds, cs);

        shader = shader.GetNext("shader");
    }

    ATOMIC_LOGDEBUG("End precaching shaders");
}

}
