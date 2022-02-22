// #version 300 es
#version 140

precision mediump int;
precision mediump float;

in vec3 vertColor;
in vec2 texCoords;
flat in ivec2 squareIndex;

// this is the last fragment shader so only output is gl_FragColor

uniform float borderWidth; // units are in square widths
uniform vec3  borderColor; // defaults to black

uniform ivec2 squareDim = ivec2(8, 8);

// gl_FragColor might be specific to 1.40...?
void main() {
  // if fragment in border then color that shit accordingly
  bool isBorder = texCoords.x < borderWidth || texCoords.x > 1. - borderWidth
               || texCoords.y < borderWidth || texCoords.y > 1. - borderWidth;
  // still on the border if on the edges
  if (squareIndex.x == 0 && texCoords.x < 2*borderWidth)                  isBorder = true;
  if (squareIndex.x == squareDim.x-1 && texCoords.x > (1. - 2*borderWidth)) isBorder = true;
  if (squareIndex.y == 0 && texCoords.y > (1. - 2*borderWidth)) isBorder = true;
  if (squareIndex.y == squareDim.y-1 && texCoords.y < 2*borderWidth) isBorder = true;

  // gl_FragColor.a doesn't seem to do anything
  if (isBorder)
    gl_FragColor.rgb = borderColor;
  else
    gl_FragColor.rgb = vertColor;

}
