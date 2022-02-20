#version 140

in vec4 vertColor;
in vec2 texCoords;

uniform float borderWidth = 0.01; // units are texture space
uniform vec3  borderColor; // defaults to black

// gl_FragColor might be specific to 1.40...?
void main() {
  // if fragment in border then color that shit accordingly
  if (     texCoords.x < borderWidth || texCoords.x > 1. - borderWidth
        || texCoords.y < borderWidth || texCoords.y > 1. - borderWidth)
    gl_FragColor = vec4(borderColor.r, borderColor.g, borderColor.b, 1.);
  else
    gl_FragColor = vertColor;
}
