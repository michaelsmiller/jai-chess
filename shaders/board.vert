#version 140

// @note: need version 3.30 for layout syntax, so order matters here
in vec2 pos;
in vec2 vertTexCoords; // for passing to fragment shader
in ivec2 vSquareIndex;

out vec3 vertColor;
out vec2 texCoords;

// 'flat' = not to try to interpolate
flat out ivec2 squareIndex;


uniform vec3 blackColor;
uniform vec3 whiteColor;


void main() {
  gl_Position = vec4(pos.x, pos.y, 0., 1.);

  texCoords = vertTexCoords;
  squareIndex = vSquareIndex;

  int isWhite = (int(squareIndex.x%2==0) ^ int(squareIndex.y%2==0)); // 0 or 1
  if (isWhite == 0)
    vertColor = whiteColor.rgb;
  else
    vertColor = blackColor.rgb;
}
