// This shader is from the OpenGL Programming Guide, 8th edition, page 378 - 379

// FRAGMENT shader for multiple lights

#version 430 core

// Point light: isLocal(GL_FALSE), isSpot(GL_FALSE) : need position only
// Spot light: isLocal(GL_FALSE), isSpot(GL_TRUE) : need position + coneDirection + spotCosCutOff + spotExponent
// Direction light: isLocal(GL_TRUE) : Need "halfVector"  (a "fast" form of direction)

struct LightProperties
{
	bool isEnabled;			// GL_FALSE, GL_TRUE
	bool isLocal;			// Only for directional lights
	bool isSpot;
	vec3 ambient;			// Like "color" but a lot less (0.2, 0.2, 0.2)
	vec3 color;				// Tip: make it a plain, boring white light (1.0, 1.0, 1.0)
	vec3 position;			// Point or spot
	vec3 halfVector;			// Only used for directional lights.
	// See code below to see how it's calculated.
	vec3 coneDirection;		// Spot lights
	float spotCosCutoff;	// Spot lights
	float spotExponent;		// Spot lights
	float constantAttenuation;
	float linearAttenuation;
	float quadraticAttenuation;
};



// the set of lights to apply, per invocation of this shader
const int MaxLights = 15;
uniform LightProperties Lights[MaxLights];

// ADDED on October 17, 2014
uniform float Shininess;
uniform float Strength;

uniform mat4 WorldMatrix;    		// aka ModelMatrix
uniform mat4 ProjectionMatrix;


smooth in vec4 ex_Position;
smooth in vec3 ex_Normal;			// Note Normal is a vec3
smooth in vec4 ex_Tex_UV;



out vec4 out_Color;		// If you don't say otherwise, this is the pixel colour



uniform sampler2D texture1;


//For Shadow
uniform sampler2D shadowMap;
uniform mat4 depthMVP;


// FRAGMENT

void calcLightContrib(inout vec4 outColour, in vec4 surfaceColour)
{
	vec2 poissonDisk[4] = vec2[](
	vec2( -0.94201624, -0.39906216 ),
	vec2( 0.94558609, -0.76890725 ),
	vec2( -0.094184101, -0.92938870 ),
	vec2( 0.34495938, 0.29387760 )
	);
	//........................................................

	vec4 pos = ex_Position;
	pos.y -= 0.5f;
	vec4 ShadowCoord = depthMVP * pos;
	
	ShadowCoord/=ShadowCoord.w;

	float shadow = 1.0;


	float bias = 0.001;


		if ( texture2D( shadowMap, ShadowCoord.xy ).r  <  ShadowCoord.z-bias){
			shadow = 0.5;
		}

		
	


	//...........................

	vec3 scatteredLight = vec3(0.0);		// or, to a global ambient light
	vec3 reflectedLight = vec3(0.0);

	// loop over all the lights
	for (int light = 0; light < MaxLights; ++light)
	{
		if (!Lights[light].isEnabled)
			continue;

		vec3 halfVector;
		vec3 lightDirection = Lights[light].position;
		float attenuation = 1.0;

		// for local lights, compute per-fragment direction,
		// half-vector, and attenuation
		if (Lights[light].isLocal)			// NOT Directional lighting
		{
			lightDirection = lightDirection - vec3(ex_Position);
			float lightDistance = length(lightDirection);
			lightDirection = lightDirection / lightDistance;

			attenuation = 1.0f /
				(Lights[light].constantAttenuation
				+ Lights[light].linearAttenuation * lightDistance
				+ Lights[light].quadraticAttenuation * lightDistance * lightDistance);

			if (Lights[light].isSpot)
			{
				float spotCos = dot(lightDirection,
					-Lights[light].coneDirection);

				if (spotCos < Lights[light].spotCosCutoff)
				{
					attenuation = 0.0f;
				}
				else
				{
					attenuation *= pow(spotCos,
						Lights[light].spotExponent);
				}
			} // if (Lights[light].isSpot)

			halfVector = normalize(lightDirection);
		}
		else
		{
			halfVector = Lights[light].halfVector;
		}

		float diffuse = max(0.0, dot(ex_Normal, lightDirection));
		float specular = max(0.0, dot(ex_Normal, halfVector));

		if (diffuse <= 0.0)
		{
			specular = 0.0;
		}
		else
		{
			specular = pow(specular,Shininess) * Strength;
		}

		// Accumulate all the lights effects
		scatteredLight += Lights[light].ambient * attenuation +
			Lights[light].color  * attenuation;

		reflectedLight += Lights[light].color * specular * attenuation;
	}// for ( int light = 0, ...

	vec3 rgb = min(surfaceColour.rgb * scatteredLight + reflectedLight, vec3(1.0));
	//vec3 rgb = min(scatteredLight + reflectedLight, vec3(1.0) );



	//outColour = shadow * vec4(rgb.r, rgb.g, rgb.b , surfaceColour.a) ;
	outColour =  vec4(rgb.r, rgb.g, rgb.b , surfaceColour.a) ;
	
}





void main(void)
{
	vec4 surfaceColour = texture2D(texture1, ex_Tex_UV.xy);
 
	calcLightContrib(out_Color, surfaceColour);
	//out_Color = surfaceColour;
}