variable "DOCKERHUB_REPO" {
  default = "aykutmursalo"
}

variable "DOCKERHUB_IMG" {
  default = "fffa"
}

variable "RELEASE_VERSION" {
  default = "latest"
}

group "default" {
  targets = ["base", "fast-fp8", "fast-bf16", "dev-fp8", "dev_bf16"]
}

target "base" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "base"
  platforms  = ["linux/amd64"]
  tags       = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:${RELEASE_VERSION}-base"]
}

# fast-fp8 modeli
target "fast-fp8" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "final"
  inherits   = ["base"]
  args = {
    MODEL_TYPE = "fast-fp8"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:${RELEASE_VERSION}-fast-fp8"]
}

# fast-bf16 modeli
target "fast-bf16" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "final"
  inherits   = ["base"]
  args = {
    MODEL_TYPE = "fast-bf16"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:${RELEASE_VERSION}-fast-bf16"]
}

# dev-fp8 modeli
target "dev-fp8" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "final"
  inherits   = ["base"]
  args = {
    MODEL_TYPE = "dev-fp8"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:${RELEASE_VERSION}-dev-fp8"]
}

# dev-bf16 modeli
target "dev_bf16" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "final"
  inherits   = ["base"]
  args = {
    MODEL_TYPE = "dev_bf16"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:${RELEASE_VERSION}_dev_bf16"]
}
