// #version 300 es
#version 140

// @note: probably unnecessary
precision mediump int;
precision mediump float;

in vec2 texIndex;
in vec2 texCoords;

uniform sampler2D textureMap;

// for accessing the texture as a spritesheet
const float numPieces = 6; // 6 distinct pieces
const float spriteWidth = 1. / numPieces; // width of a piece in texture space

// const vec2 texCoords = vec2(0.5, 0.5); // @todo: remove

// gl_FragColor might be specific to 1.40...?
void main() {
  vec2 tc;
  tc.x = texIndex.x * spriteWidth + texCoords.x / numPieces;
  tc.y = texIndex.y * spriteWidth + texCoords.y / numPieces;
  vec4 texColor = texture(textureMap, tc);

  // This replaces alpha blending, but when there are multiple shaders, need to get rid of this.
  if (texColor.a == 1)
    gl_FragColor = texColor;

  // @todo: figure out what the value of gl_Position is in other shader maybe
  //        Use like a debug color or something
  gl_FragColor = vec4(1., 0., 0., 1.); // temporary
}
