// #version 300 es
#version 140

#define PI 3.1415926538;

precision mediump int;
precision mediump float;

in vec3 vertColor; // the background color of the square
in vec2 texCoords; // texture coordinates within square
flat in ivec2 squareIndex;
flat in int   squareSelected;

// this is the last fragment shader so only output is gl_FragColor

uniform float borderWidth; // units are in square widths
uniform float selectionWidth;
uniform vec3  borderColor;
uniform vec3  selectionColor;

uniform ivec2 squareDim = ivec2(8, 8);

uniform float t = 0.;
uniform float period = 3; // in seconds

uniform sampler2D defaultTexture;

bool inBorder(vec2 tex, float tol) {
  return tex.x < tol || tex.x > 1. - tol
      || tex.y < tol || tex.y > 1. - tol;
}

void main() {
  // if fragment in border then color that shit accordingly
  bool isBorder = inBorder(texCoords, borderWidth);
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

  // logic for if the square is selected;
  bool isSelected = false;
  if (squareSelected == 1) {
    isSelected = inBorder(texCoords, selectionWidth);
    if (isSelected)
      gl_FragColor.rgb = selectionColor;
  }

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
  if (!isSelected) // I don't like the selection color oscillating as well
    gl_FragColor.r = clamp(red, 0., 1.);
}
