#version 140

in int color;
in int type;
in vec2 pos;
in vec2 tex;

out vec2 texIndex;
out vec2 texCoords;

const vec3 blue = vec3(0, 0, 1);
const vec3 red = vec3(1, 0, 0);
const vec3 green = vec3(0, 1, 0);

void main() {
  gl_Position = vec4(pos.x, pos.y, 0., 1.);

  texIndex.y = float(color);
  texIndex.x = float(type);
  texCoords = tex;
}
