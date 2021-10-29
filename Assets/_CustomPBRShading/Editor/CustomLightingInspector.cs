using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;
using System;
using System.ComponentModel;
using NUnit.Framework.Internal.Commands;

//
// we need some texture combine and output tools
//
// from Unity's C# StandardShaderGUI.cs
public class CustomLightingInspector : ShaderGUI
{
    public enum WorkflowMode
    {
        Specular,
        Metallic
    }

    public enum SmoothnessMapChannel
    {
        Uniform,
        AlbedoAlpha,            // albedo alpha
        SpecularMetaillicAlpha, // specular/metaillic alpha
    }

    // blend mode
    public enum BlendMode
    {
        Opque = 0,
        Cutout,
        Fade, // Old school alpha-blending mode, fresnel does not affect amount of transparency
        Transparent, // Physically plausible transparency mode, implemented as alpha pre-multiply
    }

    private static class Styles
    {
        public static GUIContent uvSetLabel = EditorGUIUtility.TrTextContent("UV Set");

        public static GUIContent albedoText =
            EditorGUIUtility.TrTextContent("Albedo", "Albedo (RGB) and Transparency (A)");

        public static GUIContent alphaCutoffText =
            EditorGUIUtility.TrTextContent("Alpha Cutoff", "Threshold for alpha cutoff");

        public static GUIContent specularMapText =
            EditorGUIUtility.TrTextContent("Specular", "Specular (RGB) and Smoothness (A)");

        public static GUIContent metallicMapText =
            EditorGUIUtility.TrTextContent("Metallic", "Metallic (R) and Smoothness (A)");

        public static GUIContent smoothnessText = EditorGUIUtility.TrTextContent("Smoothness", "Smoothness value");

        public static GUIContent smoothnessScaleText =
            EditorGUIUtility.TrTextContent("Smoothness", "Smoothness scale factor");

        public static GUIContent smoothnessMapChannelText =
            EditorGUIUtility.TrTextContent("Source", "Smoothness texture and channel");

        public static GUIContent highlightsText =
            EditorGUIUtility.TrTextContent("Specular Highlights", "Specular Highlights");

        public static GUIContent reflectionsText = EditorGUIUtility.TrTextContent("Reflections", "Glossy Reflections");
        public static GUIContent normalMapText = EditorGUIUtility.TrTextContent("Normal Map", "Normal Map");
        public static GUIContent heightMapText = EditorGUIUtility.TrTextContent("Height Map", "Height Map (G)");
        public static GUIContent occlusionText = EditorGUIUtility.TrTextContent("Occlusion", "Occlusion (G)");
        public static GUIContent emissionText = EditorGUIUtility.TrTextContent("Color", "Emission (RGB)");

        public static GUIContent detailMaskText =
            EditorGUIUtility.TrTextContent("Detail Mask", "Mask for Secondary Maps (A)");

        public static GUIContent detailAlbedoText =
            EditorGUIUtility.TrTextContent("Detail Albedo x2", "Albedo (RGB) multiplied by 2");

        public static GUIContent detailNormalMapText = EditorGUIUtility.TrTextContent("Normal Map", "Normal Map");

        public static string primaryMapsText = "Main Maps";
        public static string secondaryMapsText = "Secondary Maps";
        public static string forwardText = "Forward Rendering Options";
        public static string renderingMode = "Rendering Mode";
        public static string advancedText = "Advanced Options";

        public static string informations =
            "Custom Lighting [Learn,Remake PBR StandardShader], Modify Unity's StandardShaderGUI Code" +
            "\n1. \n" +
            "2. \n";

        public static readonly string[] blendNames = Enum.GetNames(typeof(BlendMode));
    }

    struct RenderStateSettings
    {
        public int queue;
        public string renderType;
        public UnityEngine.Rendering.BlendMode srcBlend;
        public UnityEngine.Rendering.BlendMode dstBlend;
        public bool zWrite;
        public bool alphaTest;
        public bool alphaBlend;
        public bool alphaMultiply;

        // _ALPHATEST_ON
        // _ALPHABLEND_ON
        // _ALPHAPREMULTIPLY_ON

        // pre-defined render setting with blend mode
        public static RenderStateSettings[] modes =
        {
            // Opaque
            new RenderStateSettings()
            {
                queue = (int)RenderQueue.Geometry,
                renderType = "",
                srcBlend = UnityEngine.Rendering.BlendMode.One,
                dstBlend = UnityEngine.Rendering.BlendMode.Zero,
                zWrite = true,
                alphaBlend = false,
                alphaTest = false,
                alphaMultiply = false
            },
            // CutOut
            new RenderStateSettings()
            {
                queue = (int)RenderQueue.AlphaTest,
                renderType = "TransparentCutout",
                srcBlend = UnityEngine.Rendering.BlendMode.One,
                dstBlend = UnityEngine.Rendering.BlendMode.Zero,
                zWrite = true,
                alphaTest = true,
                alphaBlend = false,
                alphaMultiply = false
            },
            // Fade
            new RenderStateSettings()
            {
                // normal transparent setting mode
                queue = (int)RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = UnityEngine.Rendering.BlendMode.SrcAlpha,
                dstBlend = UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha,
                zWrite = false,
                alphaTest = false,
                alphaBlend = true,
                alphaMultiply = false
            },
            // Transparent
            new RenderStateSettings()
            {
                queue = (int)RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = UnityEngine.Rendering.BlendMode.One,
                dstBlend = UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha,
                zWrite = false,
                alphaTest = false,
                alphaBlend = false,
                alphaMultiply = true
            }
        };
    }

    private MaterialProperty blendMode = null;
    private MaterialProperty albedoMap = null;
    private MaterialProperty albedoColor = null;

    private MaterialProperty alphaCutoff = null;

    private MaterialProperty specularMap = null;
    private MaterialProperty specularColor = null;

    private MaterialProperty metallicMap = null;
    private MaterialProperty metallic = null;

    private MaterialProperty smoothness = null;
    private MaterialProperty smoothnessScale = null;
    private MaterialProperty smoothnessMapChannel = null;

    private MaterialProperty highlights = null;
    private MaterialProperty reflections = null;

    private MaterialProperty bumpScale = null;
    private MaterialProperty bumpMap = null;

    private MaterialProperty occlusionStrength = null;
    private MaterialProperty occlusionMap = null;

    private MaterialProperty emissionColorForRendering = null;
    private MaterialProperty emissionMap = null;
    private MaterialProperty detailMask = null;
    private MaterialProperty detailAlbedoMap = null;
    private MaterialProperty detailNormalMapScale = null;
    private MaterialProperty detailNormalMap = null;
    private MaterialProperty uvSetSecondary = null;

    private MaterialEditor m_MaterialEditor;

    // default using specular flow
    private WorkflowMode m_WorkflowMode = WorkflowMode.Specular;
    private bool m_FirstTimeApply = true;

    public void FindProperties(MaterialProperty[] props)
    {
        blendMode = FindProperty("_Mode", props);
        albedoMap = FindProperty("_MainTex", props);
        albedoColor = FindProperty("_Color", props);
        alphaCutoff = FindProperty("_Cutoff", props);
        specularMap = FindProperty("_SpecGlossMap", props, false);
        specularColor = FindProperty("_SpecColor", props, false);
        metallicMap = FindProperty("_MetallicGlossMap", props, false);
        metallic = FindProperty("_Metallic", props, false);
        if (specularMap != null && specularColor != null)
            m_WorkflowMode = WorkflowMode.Specular;
        else if (metallicMap != null && metallic != null)
            m_WorkflowMode = WorkflowMode.Metallic;
        // else
        //     m_WorkflowMode = WorkflowMode.Dielectric;
        smoothness = FindProperty("_Glossiness", props);
        smoothnessScale = FindProperty("_GlossMapScale", props, false);
        smoothnessMapChannel = FindProperty("_SmoothnessTextureChannel", props, false);
        highlights = FindProperty("_SpecularHighlights", props, false);
        reflections = FindProperty("_GlossyReflections", props, false);
        bumpScale = FindProperty("_BumpScale", props);
        bumpMap = FindProperty("_BumpMap", props);
        // heigtMapScale = FindProperty("_Parallax", props);
        // heightMap = FindProperty("_ParallaxMap", props);
        occlusionStrength = FindProperty("_OcclusionStrength", props);
        occlusionMap = FindProperty("_OcclusionMap", props);
        emissionColorForRendering = FindProperty("_EmissionColor", props);
        emissionMap = FindProperty("_EmissionMap", props);
        detailMask = FindProperty("_DetailMask", props);
        detailAlbedoMap = FindProperty("_DetailAlbedoMap", props);
        detailNormalMapScale = FindProperty("_DetailNormalMapScale", props);
        detailNormalMap = FindProperty("_DetailNormalMap", props);
        uvSetSecondary = FindProperty("_UVSec", props);
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
    {
        FindProperties(props);
        m_MaterialEditor = materialEditor;
        Material material = materialEditor.target as Material;

        if (m_FirstTimeApply)
        {
            MaterialChanged(material, m_WorkflowMode);
            m_FirstTimeApply = false;
        }

        ShaderPropertiesGUI(material);
    }

    public void ShaderPropertiesGUI(Material material)
    {
        // Use default labelWidth
        EditorGUIUtility.labelWidth = 0f;
        // Detect any changes to the material
        EditorGUI.BeginChangeCheck();
        {
            EditorGUILayout.HelpBox(Styles.informations, MessageType.Info);

            BlendModePopup();
            // Primary properties
            GUILayout.Label(Styles.primaryMapsText, EditorStyles.boldLabel);
            DoAlbedoArea(material);
            DoSpecularMatallicArea();
            DoNormalArea();
            // m_MaterialEditor.TexturePropertySingleLine(Styles.heightMapText, heightMap, heightMap.textureValue != null ? heigtMapScale : null);
            m_MaterialEditor.TexturePropertySingleLine(Styles.occlusionText, occlusionMap,
                occlusionMap.textureValue != null ? occlusionStrength : null);
            m_MaterialEditor.TexturePropertySingleLine(Styles.detailMaskText, detailMask);
            DoEmissionArea(material);
            EditorGUI.BeginChangeCheck();
            m_MaterialEditor.TextureScaleOffsetProperty(albedoMap);
            if (EditorGUI.EndChangeCheck())
                emissionMap.textureScaleAndOffset = albedoMap.textureScaleAndOffset;
            EditorGUILayout.Space(10);

            // Secondary properties
            GUILayout.Label(Styles.secondaryMapsText, EditorStyles.boldLabel);
            m_MaterialEditor.TexturePropertySingleLine(Styles.detailAlbedoText, detailAlbedoMap);
            m_MaterialEditor.TexturePropertySingleLine(Styles.detailNormalMapText, detailNormalMap,
                detailNormalMapScale);
            m_MaterialEditor.TextureScaleOffsetProperty(detailAlbedoMap);
            // m_MaterialEditor.ShaderProperty(uvSetSecondary, Styles.uvSetLabel.text);

            // Third properties
            GUILayout.Label(Styles.forwardText, EditorStyles.boldLabel);
            if (highlights != null)
                m_MaterialEditor.ShaderProperty(highlights, Styles.highlightsText);
            if (reflections != null)
                m_MaterialEditor.ShaderProperty(reflections, Styles.reflectionsText);
        }
        if (EditorGUI.EndChangeCheck())
        {
            foreach (var obj in blendMode.targets)
            {
                MaterialChanged((Material)obj, m_WorkflowMode);
            }
        }

        EditorGUILayout.Space();
    }

    void BlendModePopup()
    {
        EditorGUI.showMixedValue = blendMode.hasMixedValue;
        var mode = (BlendMode)blendMode.floatValue;
        EditorGUI.BeginChangeCheck();
        mode = (BlendMode)EditorGUILayout.Popup(Styles.renderingMode, (int)mode, Styles.blendNames);
        if (EditorGUI.EndChangeCheck())
        {
            m_MaterialEditor.RegisterPropertyChangeUndo("Rendering Mode");
            blendMode.floatValue = (float)mode;
        }

        EditorGUI.showMixedValue = false;
    }

    void DoNormalArea()
    {
        m_MaterialEditor.TexturePropertySingleLine(Styles.normalMapText, bumpMap,
            bumpMap.textureValue != null ? bumpScale : null);
        // we can't access BuildTargetDiscovery just skip
        // if (bumpScale.floatValue != 1
        //     && BuildTargetDiscovery.PlatformHasFlag(EditorUserBuildSettings.activeBuildTarget, TargetAttributes.HasIntegratedGPU))
        //     if (m_MaterialEditor.HelpBoxWithButton(
        //         EditorGUIUtility.TrTextContent("Bump scale is not supported on mobile platforms"),
        //         EditorGUIUtility.TrTextContent("Fix Now")))
        //     {
        //         bumpScale.floatValue = 1;
        //     }
    }

    void DoAlbedoArea(Material material)
    {
        m_MaterialEditor.TexturePropertySingleLine(Styles.albedoText, albedoMap, albedoColor);
        if (((BlendMode)material.GetFloat("_Mode") == BlendMode.Cutout))
        {
            m_MaterialEditor.ShaderProperty(alphaCutoff, Styles.alphaCutoffText.text,
                MaterialEditor.kMiniTextureFieldLabelIndentLevel + 1);
        }
    }

    // Emission Area
    void DoEmissionArea(Material material)
    {
        if (m_MaterialEditor.EmissionEnabledProperty())
        {
            bool hadEmissionTexture = emissionMap.textureValue != null;
            // Texture and HDR color controls
            m_MaterialEditor.TexturePropertyWithHDRColor(Styles.emissionText, emissionMap, emissionColorForRendering,
                false);
            // If texture was assigned and color was black set color to white
            float brightness = emissionColorForRendering.colorValue.maxColorComponent;
            if (emissionMap.textureValue != null && !hadEmissionTexture && brightness <= 0f)
                emissionColorForRendering.colorValue = Color.white;

            // change the GI flag and fix it up with emissive as black if necessary
            m_MaterialEditor.LightmapEmissionFlagsProperty(MaterialEditor.kMiniTextureFieldLabelIndentLevel, true);
        }
    }

    void DoSpecularMatallicArea()
    {
        bool hasGlossMap = false;
        if (m_WorkflowMode == WorkflowMode.Specular)
        {
            hasGlossMap = specularMap.textureValue != null;
            m_MaterialEditor.TexturePropertySingleLine(Styles.specularMapText, specularMap,
                hasGlossMap ? null : specularColor);
        }
        else if (m_WorkflowMode == WorkflowMode.Metallic)
        {
            hasGlossMap = metallicMap.textureValue != null;
            m_MaterialEditor.TexturePropertySingleLine(Styles.metallicMapText, metallicMap,
                hasGlossMap ? null : metallic);
        }

        bool showSmoothnessScale = hasGlossMap;
        if (smoothnessMapChannel != null)
        {
            int smoothnessChannel = (int)smoothnessMapChannel.floatValue;
            if (smoothnessChannel == (int)SmoothnessMapChannel.AlbedoAlpha)
                showSmoothnessScale = true;
        }

        int indentation = 2; // align with labels of texture properties
        m_MaterialEditor.ShaderProperty(showSmoothnessScale ? smoothnessScale : smoothness,
            showSmoothnessScale ? Styles.smoothnessScaleText : Styles.smoothnessText, indentation);

        ++indentation;
        if (smoothnessMapChannel != null)
            m_MaterialEditor.ShaderProperty(smoothnessMapChannel, Styles.smoothnessMapChannelText, indentation);
    }

    public static void SetUpMaterialWithRenderingMode(
        Material material,
        WorkflowMode flowmode,
        BlendMode blendmode)
    {
        RenderStateSettings setting = RenderStateSettings.modes[(int)blendmode];

        material.SetOverrideTag("RenderType", setting.renderType);
        material.SetInt("_SrcBlend", (int)setting.srcBlend);
        material.SetInt("_DstBlend", (int)setting.dstBlend);
        material.SetInt("_ZWrite", setting.zWrite ? 1 : 0);
        SetKeyWord(material, "_ALPHATEST_ON", setting.alphaTest);
        SetKeyWord(material, "_ALPHABLEND_ON", setting.alphaBlend);
        SetKeyWord(material, "_ALPHAPREMULTIPLY_ON", setting.alphaMultiply);
        material.renderQueue = setting.queue;
    }

    static void MaterialChanged(Material material, WorkflowMode workFlowMode)
    {
        // need override queue?
        BlendMode mode = (BlendMode)material.GetFloat("_Mode");
        SetUpMaterialWithRenderingMode(material, workFlowMode, mode);
        SetMaterialKeywords(material, workFlowMode);
    }

    static void SetKeyWord(Material m, string keyword, bool state)
    {
        if (state)
            m.EnableKeyword(keyword);
        else
            m.DisableKeyword(keyword);
    }

    // Switch Work Flow
    static void SetMaterialKeywords(Material material, WorkflowMode workflowMode)
    {
        // Note: keywords must be based on Material value not on MaterialProperty due to multi-edit & material animation
        // (MaterialProperty value might come from renderer material property block)
        SetKeyWord(material, "_NORMAL_MAP", material.GetTexture("_BumpMap") || material.GetTexture("_DetailNormalMap"));
        if (workflowMode == WorkflowMode.Specular)
        {
            // Specular Gloss Map
            SetKeyWord(material, "_SPECGLOSSMAP", material.GetTexture("_SpecGlossMap"));
        }
        else if (workflowMode == WorkflowMode.Metallic)
        {
            // Metallic Gloss Map
            SetKeyWord(material, "_METALLICGLOSSMAP", material.GetTexture("_MetallicGlossMap"));
        }

        SetKeyWord(material, "_DETAIL_MULX2",
            material.GetTexture("_DetailAlbedoMap") || material.GetTexture("_DetailNormalMap"));
        // A material's GI flag internally keeps track of whether emission is enabled at all, it's enabled but has no effect
        // or is enabled and may be modified at runtime. This state depends on the values of the current flag and emissive color.
        // The fixup routine makes sure that the material is in the correct state if/when changes are made to the mode or color.
        MaterialEditor.FixupEmissiveFlag(material);
        bool shouldEmissionBeEnabled = (material.globalIlluminationFlags & MaterialGlobalIlluminationFlags.EmissiveIsBlack) == 0;
        SetKeyWord(material, "_EMISSION", shouldEmissionBeEnabled);
        
        if (material.HasProperty("_SmoothnessTextureChannel"))
        {
            SetKeyWord(material, "_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A", GetSmoothnessMapChannel(material) == SmoothnessMapChannel.AlbedoAlpha);
        }
    }

    static SmoothnessMapChannel GetSmoothnessMapChannel(Material material)
    {
        int ch = (int)material.GetFloat("_SmoothnessTextureChannel");
        if (ch == (int)SmoothnessMapChannel.AlbedoAlpha)
            return SmoothnessMapChannel.AlbedoAlpha;
        else
            return SmoothnessMapChannel.SpecularMetaillicAlpha;
    }
}