// #version 300 es
#version 140

#define PI 3.1415926538;

precision mediump int;
precision mediump float;

in vec3 vertColor; // the background color of the square
in vec2 texCoords; // texture coordinates within square
flat in ivec2 squareIndex;

// this is the last fragment shader so only output is gl_FragColor

uniform float borderWidth; // units are in square widths
uniform vec3  borderColor; // defaults to black

uniform ivec2 squareDim = ivec2(8, 8);

uniform float t = 0.;
uniform float period = 3; // in seconds

uniform sampler2D defaultTexture;

// for accessing the texture as a spritesheet
const float numPieces = 6; // 6 distinct pieces
const float spriteWidth = 1. / numPieces;

// gl_FragColor might be specific to 1.40...?
void main() {
  // if fragment in border then color that shit accordingly
  bool isBorder = texCoords.x < borderWidth || texCoords.x > 1. - borderWidth
               || texCoords.y < borderWidth || texCoords.y > 1. - borderWidth;
  // still on the border if on the edges
  if (squareIndex.x == squareDim.x-1 && texCoords.x > (1. - 2*borderWidth)) isBorder = true;
  if (squareIndex.y == squareDim.y-1 && texCoords.y > (1. - 2*borderWidth)) isBorder = true;
  if (squareIndex.x == 0 && texCoords.x < 2*borderWidth)                    isBorder = true;
  if (squareIndex.y == 0 && texCoords.y < 2*borderWidth)                    isBorder = true;

  // gl_FragColor.a doesn't seem to do anything
  if (isBorder)
    gl_FragColor.rgb = borderColor;
  else
    gl_FragColor.rgb = vertColor;

  // debug, alpha blend?

  // everything below is to play with dynamism
  float red = gl_FragColor.r;
  float dr = 1. - red;
  if (red > dr)
    dr = -red;

  float inv_period = 1. / period;
  float angle = 2. * PI;
  angle *= t * inv_period;
  float addition = dr * sin(angle);
  red = red + 0.2 * addition;
  gl_FragColor.r = clamp(red, 0., 1.);

  if (squareIndex.x == 1 && squareIndex.y == 1 && !isBorder) {
    vec2 piece = vec2(1, 1); // white king
    vec2 tc = vec2(0, 0);
    tc.x = piece.x * spriteWidth + texCoords.x / numPieces;
    tc.y = piece.y * spriteWidth + texCoords.y / numPieces;
    vec4 texColor = texture(defaultTexture, tc);
    if (texColor.a == 1)
      gl_FragColor = texColor;
  }
}
