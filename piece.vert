#version 140

// @note: need version 3.30 for layout syntax, so order matters here
in int color;
in int type;
in vec2 pos;
in vec2 tex;

out vec2 texIndex;
out vec2 texCoords;

void main() {
  gl_Position = vec4(pos.x, pos.y, 0., 1.);
  texIndex.y = float(color);
  texIndex.x = float(type);
  texCoords = tex;
}
