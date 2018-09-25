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

#include "../Core/Context.h"
#include "../Core/ProcessUtils.h"
#include "../Core/Profiler.h"
#include "../Graphics/Graphics.h"
#include "../Graphics/Technique.h"
#include "../Graphics/ShaderVariation.h"
#include "../IO/Log.h"
#include "../Resource/ResourceCache.h"
#include "../Resource/XMLFile.h"

#include "../DebugNew.h"

namespace Atomic
{

extern const char* cullModeNames[];

const char* blendModeNames[] =
{
    "replace",
    "add",
    "multiply",
    "alpha",
    "addalpha",
    "premulalpha",
    "invdestalpha",
    "subtract",
    "subtractalpha",
    0
};

static const char* compareModeNames[] =
{
    "always",
    "equal",
    "notequal",
    "less",
    "lessequal",
    "greater",
    "greaterequal",
    0
};

static const char* lightingModeNames[] =
{
    "unlit",
    "pervertex",
    "perpixel",
    0
};

Pass::Pass(const String& name) :
    blendMode_(BLEND_REPLACE),
    cullMode_(MAX_CULLMODES),
    depthTestMode_(CMP_LESSEQUAL),
    lightingMode_(LIGHTING_UNLIT),
    shadersLoadedFrameNumber_(0),
    alphaToCoverage_(false),
    depthWrite_(true),
    isDesktop_(false)
{
    name_ = name.ToLower();
    index_ = Technique::GetPassIndex(name_);

    // Guess default lighting mode from pass name
    if (index_ == Technique::basePassIndex || index_ == Technique::alphaPassIndex || index_ == Technique::materialPassIndex ||
        index_ == Technique::deferredPassIndex)
        lightingMode_ = LIGHTING_PERVERTEX;
    else if (index_ == Technique::lightPassIndex || index_ == Technique::litBasePassIndex || index_ == Technique::litAlphaPassIndex)
        lightingMode_ = LIGHTING_PERPIXEL;
}

Pass::~Pass()
{
}

void Pass::SetBlendMode(BlendMode mode)
{
    blendMode_ = mode;
}

void Pass::SetCullMode(CullMode mode)
{
    cullMode_ = mode;
}

void Pass::SetDepthTestMode(CompareMode mode)
{
    depthTestMode_ = mode;
}

void Pass::SetLightingMode(PassLightingMode mode)
{
    lightingMode_ = mode;
}

void Pass::SetDepthWrite(bool enable)
{
    depthWrite_ = enable;
}

void Pass::SetAlphaToCoverage(bool enable)
{
    alphaToCoverage_ = enable;
}


void Pass::SetIsDesktop(bool enable)
{
    isDesktop_ = enable;
}

void Pass::SetVertexShader(const String& name)
{
    vertexShaderName_ = name;
    ReleaseShaders();
}

void Pass::SetPixelShader(const String& name)
{
    pixelShaderName_ = name;
    ReleaseShaders();
}

void Pass::SetGeometryShader(const String& name)
{
    geometryShaderName_ = name;
    ReleaseShaders();
}

void Pass::SetHullShader(const String& name)
{
    hullShaderName_ = name;
    ReleaseShaders();
}

void Pass::SetDomainShader(const String& name)
{
    domainShaderName_ = name;
    ReleaseShaders();
}

void Pass::SetComputeShader(const String& name)
{
    computeShaderName_ = name;
    ReleaseShaders();
}

void Pass::SetVertexShaderDefines(const String& defines)
{
    vertexShaderDefines_ = defines;
    ReleaseShaders();
}

void Pass::SetPixelShaderDefines(const String& defines)
{
    pixelShaderDefines_ = defines;
    ReleaseShaders();
}

void Pass::SetGeometryShaderDefines(const String& defines)
{
    geometryShaderDefines_ = defines;
    ReleaseShaders();
}

void Pass::SetHullShaderDefines(const String& defines)
{
    hullShaderDefines_ = defines;
    ReleaseShaders();
}

void Pass::SetDomainShaderDefines(const String& defines)
{
    domainShaderDefines_ = defines;
    ReleaseShaders();
}

void Pass::SetComputeShaderDefines(const String& defines)
{
    computeShaderDefines_ = defines;
    ReleaseShaders();
}

void Pass::SetVertexShaderDefineExcludes(const String& excludes)
{
    vertexShaderDefineExcludes_ = excludes;
    ReleaseShaders();
}

void Pass::SetPixelShaderDefineExcludes(const String& excludes)
{
    pixelShaderDefineExcludes_ = excludes;
    ReleaseShaders();
}

void Pass::SetGeometryShaderDefineExcludes(const String& excludes)
{
    geometryShaderDefineExcludes_ = excludes;
    ReleaseShaders();
}

void Pass::SetHullShaderDefineExcludes(const String& excludes)
{
    hullShaderDefineExcludes_ = excludes;
    ReleaseShaders();
}

void Pass::SetDomainShaderDefineExcludes(const String& excludes)
{
    domainShaderDefineExcludes_ = excludes;
    ReleaseShaders();
}

void Pass::SetComputeShaderDefineExcludes(const String& excludes)
{
    computeShaderDefineExcludes_ = excludes;
    ReleaseShaders();
}

void Pass::ReleaseShaders()
{
    vertexShaders_.Clear();
    pixelShaders_.Clear();
    geometryShaders_.Clear();
    hullShaders_.Clear();
    domainShaders_.Clear();
    computeShaders_.Clear();

    extraVertexShaders_.Clear();
    extraPixelShaders_.Clear();
    extraGeometryShaders_.Clear();
    extraHullShaders_.Clear();
    extraDomainShaders_.Clear();
    extraComputeShaders_.Clear();
}

void Pass::MarkShadersLoaded(unsigned frameNumber)
{
    shadersLoadedFrameNumber_ = frameNumber;
}

String Pass::GetEffectiveVertexShaderDefines() const
{
    // Prefer to return just the original defines if possible
    if (vertexShaderDefineExcludes_.Empty())
        return vertexShaderDefines_;

    Vector<String> vsDefines = vertexShaderDefines_.Split(' ');
    Vector<String> vsExcludes = vertexShaderDefineExcludes_.Split(' ');
    for (unsigned i = 0; i < vsExcludes.Size(); ++i)
        vsDefines.Remove(vsExcludes[i]);

    return String::Joined(vsDefines, " ");
}

String Pass::GetEffectivePixelShaderDefines() const
{
    // Prefer to return just the original defines if possible
    if (pixelShaderDefineExcludes_.Empty())
        return pixelShaderDefines_;

    Vector<String> psDefines = pixelShaderDefines_.Split(' ');
    Vector<String> psExcludes = pixelShaderDefineExcludes_.Split(' ');
    for (unsigned i = 0; i < psExcludes.Size(); ++i)
        psDefines.Remove(psExcludes[i]);

    return String::Joined(psDefines, " ");
}

String Pass::GetEffectiveGeometryShaderDefines() const
{
    // Prefer to return just the original defines if possible
    if (geometryShaderDefineExcludes_.Empty())
        return geometryShaderDefines_;

    Vector<String> gsDefines = geometryShaderDefines_.Split(' ');
    Vector<String> gsExcludes = geometryShaderDefineExcludes_.Split(' ');
    for (unsigned i = 0; i < gsExcludes.Size(); ++i)
        gsDefines.Remove(gsExcludes[i]);

    return String::Joined(gsDefines, " ");
}

String Pass::GetEffectiveHullShaderDefines() const
{
    // Prefer to return just the original defines if possible
    if (hullShaderDefineExcludes_.Empty())
        return hullShaderDefines_;

    Vector<String> hsDefines = hullShaderDefines_.Split(' ');
    Vector<String> hsExcludes = hullShaderDefineExcludes_.Split(' ');
    for (unsigned i = 0; i < hsExcludes.Size(); ++i)
        hsDefines.Remove(hsExcludes[i]);

    return String::Joined(hsDefines, " ");
}

String Pass::GetEffectiveDomainShaderDefines() const
{
    // Prefer to return just the original defines if possible
    if (domainShaderDefineExcludes_.Empty())
        return domainShaderDefines_;

    Vector<String> dsDefines = domainShaderDefines_.Split(' ');
    Vector<String> dsExcludes = domainShaderDefineExcludes_.Split(' ');
    for (unsigned i = 0; i < dsExcludes.Size(); ++i)
        dsDefines.Remove(dsExcludes[i]);

    return String::Joined(dsDefines, " ");
}

String Pass::GetEffectiveComputeShaderDefines() const
{
    // Prefer to return just the original defines if possible
    if (computeShaderDefineExcludes_.Empty())
        return computeShaderDefines_;

    Vector<String> csDefines = computeShaderDefines_.Split(' ');
    Vector<String> csExcludes = computeShaderDefineExcludes_.Split(' ');
    for (unsigned i = 0; i < csExcludes.Size(); ++i)
        csDefines.Remove(csExcludes[i]);

    return String::Joined(csDefines, " ");
}

Vector<SharedPtr<ShaderVariation> >& Pass::GetVertexShaders(const StringHash& extraDefinesHash)
{
    // If empty hash, return the base shaders
    if (!extraDefinesHash.Value())
        return vertexShaders_;
    else
        return extraVertexShaders_[extraDefinesHash];
}

Vector<SharedPtr<ShaderVariation> >& Pass::GetPixelShaders(const StringHash& extraDefinesHash)
{
    if (!extraDefinesHash.Value())
        return pixelShaders_;
    else
        return extraPixelShaders_[extraDefinesHash];
}

Vector<SharedPtr<ShaderVariation> >& Pass::GetGeometryShaders(const StringHash& extraDefinesHash)
{
    // If empty hash, return the base shaders
    if (!extraDefinesHash.Value())
        return geometryShaders_;
    else
        return extraGeometryShaders_[extraDefinesHash];
}

Vector<SharedPtr<ShaderVariation> >& Pass::GetHullShaders(const StringHash& extraDefinesHash)
{
    if (!extraDefinesHash.Value())
        return hullShaders_;
    else
        return extraHullShaders_[extraDefinesHash];
}

Vector<SharedPtr<ShaderVariation> >& Pass::GetDomainShaders(const StringHash& extraDefinesHash)
{
    // If empty hash, return the base shaders
    if (!extraDefinesHash.Value())
        return domainShaders_;
    else
        return extraDomainShaders_[extraDefinesHash];
}

Vector<SharedPtr<ShaderVariation> >& Pass::GetComputeShaders(const StringHash& extraDefinesHash)
{
    if (!extraDefinesHash.Value())
        return computeShaders_;
    else
        return extraComputeShaders_[extraDefinesHash];
}

unsigned Technique::basePassIndex = 0;
unsigned Technique::alphaPassIndex = 0;
unsigned Technique::materialPassIndex = 0;
unsigned Technique::deferredPassIndex = 0;
unsigned Technique::lightPassIndex = 0;
unsigned Technique::litBasePassIndex = 0;
unsigned Technique::litAlphaPassIndex = 0;
unsigned Technique::shadowPassIndex = 0;

HashMap<String, unsigned> Technique::passIndices;

Technique::Technique(Context* context) :
    Resource(context),
    isDesktop_(false)
{
#ifdef DESKTOP_GRAPHICS
    desktopSupport_ = true;
#else
    desktopSupport_ = false;
#endif
}

Technique::~Technique()
{
}

void Technique::RegisterObject(Context* context)
{
    context->RegisterFactory<Technique>();
}

bool Technique::BeginLoad(Deserializer& source)
{
    passes_.Clear();
    cloneTechniques_.Clear();

    SetMemoryUse(sizeof(Technique));

    SharedPtr<XMLFile> xml(new XMLFile(context_));
    if (!xml->Load(source))
        return false;

    XMLElement rootElem = xml->GetRoot();
    if (rootElem.HasAttribute("desktop"))
        isDesktop_ = rootElem.GetBool("desktop");

    String globalVS = rootElem.GetAttribute(ShaderTypeName[ShaderType::VS]);
    String globalPS = rootElem.GetAttribute(ShaderTypeName[ShaderType::PS]);
    String globalGS = rootElem.GetAttribute(ShaderTypeName[ShaderType::GS]);
    String globalHS = rootElem.GetAttribute(ShaderTypeName[ShaderType::HS]);
    String globalDS = rootElem.GetAttribute(ShaderTypeName[ShaderType::DS]);
    String globalCS = rootElem.GetAttribute(ShaderTypeName[ShaderType::CS]);

    String globalVSDefines = rootElem.GetAttribute(ShaderTypeDefineName[ShaderType::VS]);
    String globalPSDefines = rootElem.GetAttribute(ShaderTypeDefineName[ShaderType::PS]);
    String globalGSDefines = rootElem.GetAttribute(ShaderTypeDefineName[ShaderType::GS]);
    String globalHSDefines = rootElem.GetAttribute(ShaderTypeDefineName[ShaderType::HS]);
    String globalDSDefines = rootElem.GetAttribute(ShaderTypeDefineName[ShaderType::DS]);
    String globalCSDefines = rootElem.GetAttribute(ShaderTypeDefineName[ShaderType::CS]);

    // End with space so that the pass-specific defines can be appended
    if (!globalVSDefines.Empty())
        globalVSDefines += ' ';

    if (!globalPSDefines.Empty())
        globalPSDefines += ' ';

    if (!globalGSDefines.Empty())
        globalGSDefines += ' ';

    if (!globalHSDefines.Empty())
        globalHSDefines += ' ';

    if (!globalDSDefines.Empty())
        globalDSDefines += ' ';

    if (!globalCSDefines.Empty())
        globalCSDefines += ' ';

    XMLElement passElem = rootElem.GetChild("pass");
    while (passElem)
    {
        if (passElem.HasAttribute("name"))
        {
            Pass* newPass = CreatePass(passElem.GetAttribute("name"));

            if (passElem.HasAttribute("desktop"))
                newPass->SetIsDesktop(passElem.GetBool("desktop"));

            // Append global defines only when pass does not redefine the shader
            if (passElem.HasAttribute(ShaderTypeName[ShaderType::VS]))
            {
                newPass->SetVertexShader(passElem.GetAttribute(ShaderTypeName[ShaderType::VS]));
                newPass->SetVertexShaderDefines(passElem.GetAttribute(ShaderTypeDefineName[ShaderType::VS]));
            }
            else
            {
                newPass->SetVertexShader(globalVS);
                newPass->SetVertexShaderDefines(globalVSDefines + passElem.GetAttribute(ShaderTypeDefineName[ShaderType::VS]));
            }

            if (passElem.HasAttribute(ShaderTypeName[ShaderType::PS]))
            {
                newPass->SetPixelShader(passElem.GetAttribute(ShaderTypeName[ShaderType::PS]));
                newPass->SetPixelShaderDefines(passElem.GetAttribute(ShaderTypeDefineName[ShaderType::PS]));
            }
            else
            {
                newPass->SetPixelShader(globalPS);
                newPass->SetPixelShaderDefines(globalPSDefines + passElem.GetAttribute(ShaderTypeDefineName[ShaderType::PS]));
            }

            if (passElem.HasAttribute(ShaderTypeName[ShaderType::GS]))
            {
                newPass->SetGeometryShader(passElem.GetAttribute(ShaderTypeName[ShaderType::GS]));
                newPass->SetGeometryShaderDefines(passElem.GetAttribute(ShaderTypeDefineName[ShaderType::GS]));
            }
            else
            {
                newPass->SetGeometryShader(globalGS);
                newPass->SetGeometryShaderDefines(globalGSDefines + passElem.GetAttribute(ShaderTypeDefineName[ShaderType::GS]));
            }

            if (passElem.HasAttribute(ShaderTypeName[ShaderType::HS]))
            {
                newPass->SetHullShader(passElem.GetAttribute(ShaderTypeName[ShaderType::HS]));
                newPass->SetHullShaderDefines(passElem.GetAttribute(ShaderTypeDefineName[ShaderType::HS]));
            }
            else
            {
                newPass->SetHullShader(globalHS);
                newPass->SetHullShaderDefines(globalHSDefines + passElem.GetAttribute(ShaderTypeDefineName[ShaderType::HS]));
            }

            if (passElem.HasAttribute(ShaderTypeName[ShaderType::DS]))
            {
                newPass->SetDomainShader(passElem.GetAttribute(ShaderTypeName[ShaderType::DS]));
                newPass->SetDomainShaderDefines(passElem.GetAttribute(ShaderTypeDefineName[ShaderType::DS]));
            }
            else
            {
                newPass->SetDomainShader(globalDS);
                newPass->SetDomainShaderDefines(globalDSDefines + passElem.GetAttribute(ShaderTypeDefineName[ShaderType::DS]));
            }

            if (passElem.HasAttribute(ShaderTypeName[ShaderType::CS]))
            {
                newPass->SetComputeShader(passElem.GetAttribute(ShaderTypeName[ShaderType::CS]));
                newPass->SetComputeShaderDefines(passElem.GetAttribute(ShaderTypeDefineName[ShaderType::CS]));
            }
            else
            {
                newPass->SetComputeShader(globalCS);
                newPass->SetComputeShaderDefines(globalCSDefines + passElem.GetAttribute(ShaderTypeDefineName[ShaderType::CS]));
            }


            newPass->SetVertexShaderDefineExcludes(passElem.GetAttribute("vsexcludes"));
            newPass->SetPixelShaderDefineExcludes(passElem.GetAttribute("psexcludes"));
            newPass->SetGeometryShaderDefineExcludes(passElem.GetAttribute("gsexcludes"));
            newPass->SetHullShaderDefineExcludes(passElem.GetAttribute("hsexcludes"));
            newPass->SetDomainShaderDefineExcludes(passElem.GetAttribute("dsexcludes"));
            newPass->SetComputeShaderDefineExcludes(passElem.GetAttribute("csexcludes"));

            if (passElem.HasAttribute("lighting"))
            {
                String lighting = passElem.GetAttributeLower("lighting");
                newPass->SetLightingMode((PassLightingMode)GetStringListIndex(lighting.CString(), lightingModeNames,
                    LIGHTING_UNLIT));
            }

            if (passElem.HasAttribute("blend"))
            {
                String blend = passElem.GetAttributeLower("blend");
                newPass->SetBlendMode((BlendMode)GetStringListIndex(blend.CString(), blendModeNames, BLEND_REPLACE));
            }

            if (passElem.HasAttribute("cull"))
            {
                String cull = passElem.GetAttributeLower("cull");
                newPass->SetCullMode((CullMode)GetStringListIndex(cull.CString(), cullModeNames, MAX_CULLMODES));
            }

            if (passElem.HasAttribute("depthtest"))
            {
                String depthTest = passElem.GetAttributeLower("depthtest");
                if (depthTest == "false")
                    newPass->SetDepthTestMode(CMP_ALWAYS);
                else
                    newPass->SetDepthTestMode((CompareMode)GetStringListIndex(depthTest.CString(), compareModeNames, CMP_LESS));
            }

            if (passElem.HasAttribute("depthwrite"))
                newPass->SetDepthWrite(passElem.GetBool("depthwrite"));

            if (passElem.HasAttribute("alphatocoverage"))
                newPass->SetAlphaToCoverage(passElem.GetBool("alphatocoverage"));
        }
        else
            ATOMIC_LOGERROR("Missing pass name");

        passElem = passElem.GetNext("pass");
    }

    return true;
}

void Technique::SetIsDesktop(bool enable)
{
    isDesktop_ = enable;
}

void Technique::ReleaseShaders()
{
    for (Vector<SharedPtr<Pass> >::ConstIterator i = passes_.Begin(); i != passes_.End(); ++i)
    {
        Pass* pass = i->Get();
        if (pass)
            pass->ReleaseShaders();
    }
}

SharedPtr<Technique> Technique::Clone(const String& cloneName) const
{
    SharedPtr<Technique> ret(new Technique(context_));
    ret->SetIsDesktop(isDesktop_);
    ret->SetName(cloneName);

    // Deep copy passes
    for (Vector<SharedPtr<Pass> >::ConstIterator i = passes_.Begin(); i != passes_.End(); ++i)
    {
        Pass* srcPass = i->Get();
        if (!srcPass)
            continue;

        Pass* newPass = ret->CreatePass(srcPass->GetName());
        newPass->SetBlendMode(srcPass->GetBlendMode());
        newPass->SetDepthTestMode(srcPass->GetDepthTestMode());
        newPass->SetLightingMode(srcPass->GetLightingMode());
        newPass->SetDepthWrite(srcPass->GetDepthWrite());
        newPass->SetAlphaToCoverage(srcPass->GetAlphaToCoverage());
        newPass->SetIsDesktop(srcPass->IsDesktop());
        newPass->SetVertexShader(srcPass->GetVertexShader());
        newPass->SetPixelShader(srcPass->GetPixelShader());
        newPass->SetGeometryShader(srcPass->GetGeometryShader());
        newPass->SetHullShader(srcPass->GetHullShader());
        newPass->SetDomainShader(srcPass->GetDomainShader());
        newPass->SetComputeShader(srcPass->GetComputeShader());
        newPass->SetVertexShaderDefines(srcPass->GetVertexShaderDefines());
        newPass->SetPixelShaderDefines(srcPass->GetPixelShaderDefines());
        newPass->SetGeometryShaderDefines(srcPass->GetGeometryShaderDefines());
        newPass->SetHullShaderDefines(srcPass->GetHullShaderDefines());
        newPass->SetDomainShaderDefines(srcPass->GetDomainShaderDefines());
        newPass->SetComputeShaderDefines(srcPass->GetComputeShaderDefines());
        newPass->SetVertexShaderDefineExcludes(srcPass->GetVertexShaderDefineExcludes());
        newPass->SetPixelShaderDefineExcludes(srcPass->GetPixelShaderDefineExcludes());
        newPass->SetGeometryShaderDefineExcludes(srcPass->GetGeometryShaderDefineExcludes());
        newPass->SetHullShaderDefineExcludes(srcPass->GetHullShaderDefineExcludes());
        newPass->SetDomainShaderDefineExcludes(srcPass->GetDomainShaderDefineExcludes());
        newPass->SetComputeShaderDefineExcludes(srcPass->GetComputeShaderDefineExcludes());
    }

    return ret;
}

Pass* Technique::CreatePass(const String& name)
{
    Pass* oldPass = GetPass(name);
    if (oldPass)
        return oldPass;

    SharedPtr<Pass> newPass(new Pass(name));
    unsigned passIndex = newPass->GetIndex();
    if (passIndex >= passes_.Size())
        passes_.Resize(passIndex + 1);
    passes_[passIndex] = newPass;

    // Calculate memory use now
    SetMemoryUse((unsigned)(sizeof(Technique) + GetNumPasses() * sizeof(Pass)));

    return newPass;
}

void Technique::RemovePass(const String& name)
{
    HashMap<String, unsigned>::ConstIterator i = passIndices.Find(name.ToLower());
    if (i == passIndices.End())
        return;
    else if (i->second_ < passes_.Size() && passes_[i->second_].Get())
    {
        passes_[i->second_].Reset();
        SetMemoryUse((unsigned)(sizeof(Technique) + GetNumPasses() * sizeof(Pass)));
    }
}

bool Technique::HasPass(const String& name) const
{
    HashMap<String, unsigned>::ConstIterator i = passIndices.Find(name.ToLower());
    return i != passIndices.End() ? HasPass(i->second_) : false;
}

Pass* Technique::GetPass(const String& name) const
{
    HashMap<String, unsigned>::ConstIterator i = passIndices.Find(name.ToLower());
    return i != passIndices.End() ? GetPass(i->second_) : 0;
}

Pass* Technique::GetSupportedPass(const String& name) const
{
    HashMap<String, unsigned>::ConstIterator i = passIndices.Find(name.ToLower());
    return i != passIndices.End() ? GetSupportedPass(i->second_) : 0;
}

unsigned Technique::GetNumPasses() const
{
    unsigned ret = 0;

    for (Vector<SharedPtr<Pass> >::ConstIterator i = passes_.Begin(); i != passes_.End(); ++i)
    {
        if (i->Get())
            ++ret;
    }

    return ret;
}

Vector<String> Technique::GetPassNames() const
{
    Vector<String> ret;

    for (Vector<SharedPtr<Pass> >::ConstIterator i = passes_.Begin(); i != passes_.End(); ++i)
    {
        Pass* pass = i->Get();
        if (pass)
            ret.Push(pass->GetName());
    }

    return ret;
}

PODVector<Pass*> Technique::GetPasses() const
{
    PODVector<Pass*> ret;

    for (Vector<SharedPtr<Pass> >::ConstIterator i = passes_.Begin(); i != passes_.End(); ++i)
    {
        Pass* pass = i->Get();
        if (pass)
            ret.Push(pass);
    }

    return ret;
}

SharedPtr<Technique> Technique::CloneWithDefines(const String& vsDefines, const String& psDefines, const String& gsDefines, const String& hsDefines, const String& dsDefines, const String& csDefines)
{
    // Return self if no actual defines
    if (vsDefines.Empty() && psDefines.Empty() && gsDefines.Empty() && hsDefines.Empty() && dsDefines.Empty() && csDefines.Empty())
        return SharedPtr<Technique>(this);

    //Pair<StringHash, StringHash> key = MakePair(StringHash(vsDefines), StringHash(psDefines));
    SharedArrayPtr<StringHash> key(new StringHash[MAX_SHADER_PARAMETER_GROUPS]);

    key[ShaderType::VS] = StringHash(vsDefines);
    key[ShaderType::PS] = StringHash(psDefines);
    key[ShaderType::GS] = StringHash(gsDefines);
    key[ShaderType::HS] = StringHash(hsDefines);
    key[ShaderType::DS] = StringHash(dsDefines);
    key[ShaderType::CS] = StringHash(csDefines);

    // Return existing if possible
    HashMap<SharedArrayPtr<StringHash>, SharedPtr<Technique> >::Iterator i = cloneTechniques_.Find(key);
    if (i != cloneTechniques_.End())
        return i->second_;

    // Set same name as the original for the clones to ensure proper serialization of the material. This should not be a problem
    // since the clones are never stored to the resource cache
    i = cloneTechniques_.Insert(MakePair(key, Clone(GetName())));

    for (Vector<SharedPtr<Pass> >::ConstIterator j = i->second_->passes_.Begin(); j != i->second_->passes_.End(); ++j)
    {
        Pass* pass = (*j);
        if (!pass)
            continue;

        if (!vsDefines.Empty())
            pass->SetVertexShaderDefines(pass->GetVertexShaderDefines() + " " + vsDefines);
        if (!psDefines.Empty())
            pass->SetPixelShaderDefines(pass->GetPixelShaderDefines() + " " + psDefines);
        if (!gsDefines.Empty())
            pass->SetGeometryShaderDefines(pass->GetGeometryShaderDefines() + " " + gsDefines);
        if (!hsDefines.Empty())
            pass->SetHullShaderDefines(pass->GetHullShaderDefines() + " " + hsDefines);
        if (!dsDefines.Empty())
            pass->SetDomainShaderDefines(pass->GetDomainShaderDefines() + " " + dsDefines);
        if (!csDefines.Empty())
            pass->SetComputeShaderDefines(pass->GetComputeShaderDefines() + " " + csDefines);
    }

    return i->second_;
}

unsigned Technique::GetPassIndex(const String& passName)
{
    // Initialize built-in pass indices on first call
    if (passIndices.Empty())
    {
        basePassIndex = passIndices["base"] = 0;
        alphaPassIndex = passIndices["alpha"] = 1;
        materialPassIndex = passIndices["material"] = 2;
        deferredPassIndex = passIndices["deferred"] = 3;
        lightPassIndex = passIndices["light"] = 4;
        litBasePassIndex = passIndices["litbase"] = 5;
        litAlphaPassIndex = passIndices["litalpha"] = 6;
        shadowPassIndex = passIndices["shadow"] = 7;
    }

    String nameLower = passName.ToLower();
    HashMap<String, unsigned>::Iterator i = passIndices.Find(nameLower);
    if (i != passIndices.End())
        return i->second_;
    else
    {
        unsigned newPassIndex = passIndices.Size();
        passIndices[nameLower] = newPassIndex;
        return newPassIndex;
    }
}

}
