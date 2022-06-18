const int Steps = 800;
const float Epsilon = 0.005; // Marching epsilon
const float T=0.5;

const float rA=1.0; // Minimum ray marching distance from origin
const float rB=50.0; // Maximum

vec2 hash( vec2 p ) 
{
	p = vec2( dot(p,vec2(127.1,311.7)),
			  dot(p,vec2(269.5,183.3)) );

	return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

float noise( in vec2 p )
{
    const float K1 = 0.366025404; // (sqrt(3)-1)/2;
    const float K2 = 0.211324865; // (3-sqrt(3))/6;

	vec2 i = floor( p + (p.x+p.y)*K1 );
	
    vec2 a = p - i + (i.x+i.y)*K2;
    vec2 o = step(a.yx,a.xy);    
    vec2 b = a - o + K2;
	vec2 c = a - 1.0 + 2.0*K2;

    vec3 h = max( 0.5-vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );

	vec3 n = h*h*h*h*vec3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));

    return dot( n, vec3(70.0) );
}

float ridged(in vec2 p) {
    float value = 2.0*(0.5 - abs(0.5 - noise(p)));
    return value;
}

float turbulence(in vec2 p, in float amplitude, in float fbase, in float attenuation, in int noctave) {
    
    int i;
    float res = .0;
    float f = fbase;
    for (i = 0; i < noctave; i++) {
        res = res+amplitude*ridged(f*p);
        amplitude = amplitude*attenuation;
        f = f*2.;
    }
    return res;
}

// Transforms
vec3 rotate(vec3 p, float a, float b, float c)
{
    mat3 rotationx = mat3(
    1,      0,       0,
    0, cos(a), -sin(a),
    0, sin(a),  cos(a)
    );

    mat3 rotationy = mat3(
    cos(b), 0, -sin(b),
    0,      1,       0,
    sin(b), 0,   cos(b)
    );

    mat3 rotationz = mat3(
    cos(c), -sin(c),   0,
    sin(c),  cos(c),   0,
         0,       0,   1
    );

    return rotationx * rotationy * rotationz * p;
}


// Smooth falloff function
// r : small radius
// R : Large radius
float falloff( float r, float R )
{
   float x = clamp(r/R,0.0,1.0);
   float y = (1.0-x*x);
   return y*y*y;
}

// Primitive functions

// Point skeleton
// p : point
// c : center of skeleton
// e : energy associated to skeleton
// R : large radius
float point(vec3 p, vec3 c, float e,float R)
{
   return e*falloff(length(p-c),R);
}


// Blending
// a : field function of left sub-tree
// b : field function of right sub-tree
float Blend(float a,float b)
{
   return a+b;
}

float terrain(in vec3 p) {
    float amplitude = 0.85; // Change la nuance de gris
    float fbase = 0.18; // Zoom
    float attenuation = 0.42; // Netteté / résolution
    int noctave = 9; // Flou
    float terrain = turbulence(p.xz, amplitude, fbase, attenuation, noctave) - p.y;
    
    return terrain;
}

// p : point
float object(vec3 p)
{
   return terrain(p);
}
// Calculate object normal
// p : point
vec3 ObjectNormal(in vec3 p )
{
   float eps = 0.0001;
   vec3 n;
   float v = object(p);
   
   n.x = object( vec3(p.x+eps, p.y, p.z) ) - v;
   n.y = object( vec3(p.x, p.y+eps, p.z) ) - v;
   n.z = object( vec3(p.x, p.y, p.z+eps) ) - v;
   
   return normalize(n);
}

// Trace ray using ray marching
// o : ray origin
// u : ray direction
// h : hit
// s : Number of steps
float Trace(vec3 o, vec3 u, out bool h,out int s)
{
   h = false;

   // Don't start at the origin
   // instead move a little bit forward
   float t=rA;

   for(int i=0; i<Steps; i++)
   {
      s=i;
      vec3 p = o+t*u;
      float v = object(p);
      // Hit object (1) 
      if (v > 0.0)
      {
         s=i;
         h = true;
         break;
      }
      // Move along ray
      //t += Epsilon;
      t += max(Epsilon,-v/2.0);

      // Escape marched far away
      if (t>rB)
      {
         break;
      }
   }
   return t;
}

// Background color
vec3 background(vec3 rd)
{
   return mix(vec3(0.8, 0.8, 0.9), vec3(0.6, 0.9, 1.0), rd.y*1.0+0.25);
}

// Shading and lighting
// p : point,
// n : normal at point
vec3 Shade(vec3 p, vec3 n, int s)
{
    float y = p.y + 1.0;
    // a = bq +r
    float espacementTraits = 0.3;
    float reste = mod(y, espacementTraits);
    float quotient = (y - reste) / espacementTraits;

    // point light
    const vec3 lightPos = vec3(5.0, 5.0, 5.0);

    // Couleur des montagnes
    // Terre (marron)
    vec3 couleurBasse = vec3(94.0/255.0, 65.0/255.0, 8.0/255.0);
    vec3 couleurHaute = vec3(220.0/255.0, 206.0/255.0, 62.0/255.0);
    
    // Herbe
    couleurBasse = vec3(0.0, 0.2, 0.);
    couleurHaute = vec3(0.0, 0.5, 0.);
    vec3 lightColor = mix(couleurBasse, couleurHaute, p.y);
    
    float amplitude = 0.1; // Change la nuance de gris
    float fbase = 12.0; // Zoom
    float attenuation = 0.01; // Netteté / résolution
    int noctave = 1; // Flou
    float hauteurSommet = turbulence(p.xz, amplitude, fbase, attenuation, noctave) - p.y + 1.75;
    
    if (hauteurSommet < y) {
        lightColor = vec3(0.5, 0.25, 0.);
    }
    
    vec3 l = normalize(lightPos - p);
    
    // Not even Phong shading, use weighted cosine instead for smooth transitions
    float diff = 0.5*(1.0+dot(n, l));
    
    vec3 c =  0.5*vec3(0.5,0.5,0.5)+0.5*diff*lightColor;
    float fog = 0.7*float(s)/(float(Steps-1));
    c = (1.0-fog)*c+fog*vec3(1.0,1.0,1.0);
    
    hauteurSommet += .8;
    // NEIGE
    if (hauteurSommet <= y) {
        vec3 snow = vec3(0.9, 0.9, 0.9);
        c = mix(c, snow, 0.8); 
    }
    
    // Lignes noires
    /*float epaisseurTrait = 0.01;
    if (reste < epaisseurTrait) {
        c = vec3(0.0, 0.0, 0.0);
    }*/
    
    vec2 pointNoise = p.xz*(mod(iTime/260.0, 0.5)+0.45);
    vec2 pointNoise2 = vec2(p.x+0.013, p.z)*(mod(iTime/250.0, 0.5)+0.4);
    
    // Création du bruit pour l'eau
    amplitude = 0.1; // Change la nuance de gris
    fbase = 12.0; // Zoom
    attenuation = 0.01; // Netteté / résolution
    noctave = 1; // Flou
    float hauteurEau = turbulence(pointNoise, amplitude, fbase, attenuation, noctave) - p.y;
    
    // Mouvement de l'eau
    if (y < hauteurEau) {
        vec3 waterColorDark = vec3(0.1, 0.3, 0.8);
        vec3 waterColorClear = vec3(0.0, 0.5, 0.9);
        vec3 waterColor = mix(waterColorDark, waterColorClear, (p.y+1.)*0.5);
        
        c = mix(waterColor, c, 0.6);
    }
    
    // Reflet sur l'eau du Soleil
    if (y < 0.4 && 1.3 < hauteurEau) {
        c = mix(vec3(1.0, 1.0, 1.0), c, 0.2);
    }
    
    amplitude = 0.25; // Change la nuance de gris
    fbase = 6.0; // Zoom
    attenuation = 0.1; // Netteté / résolution
    noctave = 6; // Flou
    hauteurEau = turbulence(pointNoise, amplitude, fbase, attenuation, noctave) - p.y;
    // Reflets sous l'eau foncés
    hauteurEau = hauteurEau * -1.0;
    if (-1.0 < hauteurEau && hauteurEau < -0.95 ) {
        c = mix(vec3(1.0, 1.0, 1.0), c, 0.8);
    }
    
    hauteurEau = turbulence(pointNoise2, amplitude, fbase, attenuation, noctave) - p.y;
    // Reflets sous l'eau clairs
    hauteurEau = hauteurEau * -1.0;
    if (-1.0 < hauteurEau && hauteurEau < -0.9 ) {
        c = mix(vec3(1.0, 1.0, 1.0), c, 0.9);
    }

    return c;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
   vec2 pixel = (gl_FragCoord.xy / iResolution.xy)*2.0-1.0;

   // compute ray origin and direction
   float asp = iResolution.x / iResolution.y;
   vec3 rd = vec3(asp*pixel.x, pixel.y, -4.0);
   vec3 ro = vec3(-28.9, 3.4, -0.5);

   vec2 mouse = iMouse.xy / iResolution.xy;
   float a = -mouse.x * 2.0;
   float b = -mouse.y * 2.0;
   //rd.z = rd.z+2.0*mouse.y;
   rd = normalize(rd);
   ro = rotate(ro, 1.0, 0.0, .0);
   rd = rotate(rd, 1.0+b, 0.0, 0.0);

   // Trace ray
   bool hit;

   // Number of steps
   int s;

   float t = Trace(ro, rd, hit,s);
   vec3 pos=ro+t*rd;
   // Shade background
   vec3 rgb = background(rd);

   if (hit)
   {
      // Compute normal
      vec3 n = ObjectNormal(pos);

      // Shade object with light
      rgb = Shade(pos, n, s);
   }

   fragColor=vec4(rgb, 1.0);
}
