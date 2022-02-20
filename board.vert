#version 140

// @note: need version 3.30 for layout syntax, so order matters here
in vec2 pos;
in vec2 vertTexCoords; // for passing to fragment shader
in int isWhite; // used as a boolean

out vec4 vertColor;
out vec2 texCoords;

uniform vec3 blackColor;
uniform vec3 whiteColor;


void main() {
  gl_Position = vec4(pos.x, pos.y, 0., 1.);
  texCoords = vertTexCoords;
  // vertColor = vec4(0.5, 0.5, 0.8, 1.); // Soft Magenta
  // vertColor = vec4(squareColor.r, squareColor.g, squareColor.b, 1.); // Soft Magenta
  if (isWhite == 0)
    vertColor = vec4(whiteColor.r, whiteColor.g, whiteColor.b, 1.);
  else
    vertColor = vec4(blackColor.r, blackColor.g, blackColor.b, 1.);
}
