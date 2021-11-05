using System.Collections;
using System.Collections.Generic;
using System.Numerics;
using UnityEngine;
using Vector2 = UnityEngine.Vector2;

[ExecuteInEditMode]
public class CSharpDebugTool : MonoBehaviour
{
    public float remapinputvalue = 0.0f;
    public Vector2 remapInputRange = Vector2.zero;
    public Vector2 remapOutputRange = Vector2.zero;

    private float Unity_Remap_float(float In, float InMin, float InMax, float OutMin, float OutMax)
    {
        float Out = OutMin + (In - InMin) * (OutMax - OutMin) / (InMax - InMin);
        return Out;
    }

    private float Remap(float input, float InMin, float InMax, float OutMin, float OutMax)
    {
        float t = inverseLerp(InMin, InMax, input);
        return lerp(OutMin, OutMax, t);
    }

    // Percent to value
    private float lerp(float a, float b, float t)
    {
        // return (1 - t) * a + b * t;
        return Mathf.Lerp(a, b, t);
    }

    // Value to percent
    private float inverseLerp(float a, float b, float t)
    {
        // return (t - a) / (b - a);
        return Mathf.InverseLerp(a, b, t);
    }

    public bool printMessage = false;

    private void Update()
    {
        if (false)
        {
            float ret = Remap(
                remapinputvalue, 
                remapInputRange.x, 
                remapInputRange.y, 
                remapOutputRange.x,
                remapOutputRange.y);
            
            Debug.Log(
                $"input:{remapinputvalue},[{remapInputRange.ToString("0.00")}],[{remapOutputRange.ToString("0.00")}], ret={ret.ToString("0.000")}");
        }
    }
}