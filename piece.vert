#version 140

// @note: need version 3.30 for layout syntax, so order matters here
in int color;
in int type;
in vec2 pos;
in vec2 tex;

out vec2 texIndex;
out vec2 texCoords;

// @todo: remove debugging
out vec3 debugColor;
const vec3 blue = vec3(0, 0, 1);
const vec3 red = vec3(1, 0, 0);
const vec3 green = vec3(0, 1, 0);

void main() {
  gl_Position = vec4(pos.x, pos.y, 0., 1.);
  // vec2 p = pos * 0.25;
  // p.x = p.x - 0.75;
  // p.y = p.y + 0.5;
  // gl_Position = vec4(p.x, p.y, 0., 1.);

  texIndex.y = float(color);
  texIndex.x = float(type);
  texCoords = tex;

  if (pos.x >= 0. && pos.y >= 0)
    debugColor = blue;
  else
    debugColor = red;
}
