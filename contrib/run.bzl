# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
A rule to run a command inside a container, and commit the result.
Returns the image id of the committed container.
"""

load(
    "//container:bundle.bzl",
    "container_bundle",
)


def _impl(ctx):
    # Since we're always bundling/renaming the image in the macro, this is valid.
    load_statement = 'docker load -i %s' % ctx.file.image_tar.short_path
    image_name = ctx.attr.image_name

    # TODO: strip illegal flags from run command
    # we shouldn't allow -i or -t at the very least

    # TODO: we should probably generate a unique name here?
    # tag = time.time()
    tag = ctx.attr.image_name + ':run_and_commit'

    # Generate a shell script to execute the run statement
    ctx.actions.expand_template(
        template=ctx.file._run_tpl,
        output=ctx.outputs.executable,
        substitutions={
          "%{load_statement}": load_statement,
          "%{flags}": " ".join(ctx.attr.flags),
          "%{image}": ctx.attr.image_name,
          "%{command}": " ".join(ctx.attr.command),
          "%{tag}": tag,
          # "%{output}": ctx.attr.output,
        },
        is_executable=True,
    )

    return struct(runfiles=ctx.runfiles(files = [
            ctx.executable.image_tar,
            # ctx.file.output, # unsure if this is correct, trying to include the committed image
            ctx.file.image_tar] + 
            ctx.attr.image_tar.files.to_list() + 
            ctx.attr.image_tar.data_runfiles.files.to_list()
        ),
    )


_container_run = rule(
    attrs = {
        "flags": attr.string_list(
            doc = "list of flags to pass to run command",
            default = ['-d', '-t', '--privileged'],
        ),
        "image_tar": attr.label(
            executable = True,
            allow_files = True,
            mandatory = True,
            single_file = True,
            cfg = "target",
        ),
        "image_name": attr.string(
            doc = "name of image to run commands on",
            mandatory = True,
        ),
        "command": attr.string_list(
            doc = "command to run",
            mandatory = True,
            non_empty = True,
        ),
        "_run_tpl": attr.label(
            default = Label("//contrib:docker_run.sh.tpl"),
            allow_files = True,
            single_file = True,
        ),
        # "output": attr.output(
        #     mandatory = True,
        # )
    },
    executable = True,
    implementation = _impl,
)


def container_run(name, image, command, flags=None):
    """A macro to predictably rename the image under test before threading
    it to the container test rule."""
    intermediate_image_name = "%s:intermediate" % image.replace(':', '').replace('@', '').replace('/', '')
    image_tar_name = "intermediate_bundle_%s" % name

    # output = intermediate_image_name + '_committed.tar'

    # Give the image a predictable name when loaded
    container_bundle(
        name = image_tar_name,
        images = {
            intermediate_image_name: image,
        }
    )

    _container_run(
        name = name,
        image_name = intermediate_image_name,
        image_tar = image_tar_name + ".tar",
        flags = flags,
        command = command,
        # output = output,
    )
