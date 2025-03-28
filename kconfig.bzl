def _gen_kconfiglib_impl(repo_ctx):
    script_path = Label(":bazel_config.py")
    build_file_name = "BUILD.bazel"
    build_file_path = repo_ctx.path(build_file_name)

    repo_ctx.file(build_file_name)

    args = [
        repo_ctx.which("python3"),
        script_path,
        "--kconfig",
        str(repo_ctx.path(repo_ctx.attr.kconfig_file)),
        "gen_kconfig",
        "-o",
        build_file_path,
    ]
    result = repo_ctx.execute(args)
    if result.return_code != 0:
        fail("Failed to generate kconfig BUILD file (%d):\n%s" % (result.return_code, result.stderr))
    repo_ctx.symlink(
        repo_ctx.attr.feature_cc_library,
        "feature_cc_library.bzl",
    )

gen_kconfiglib = repository_rule(
    implementation = _gen_kconfiglib_impl,
    attrs = {
        "kconfig_file": attr.label(
            allow_single_file = True,
            default = "//:kconfig.BUILD",
        ),
        "feature_cc_library": attr.label(
            allow_single_file = True,
            default = "//:feature_cc_library.bzl",
        ),
    },
)

def _gen_projectlib_impl(repo_ctx):
    script_path = Label(":bazel_config.py")
    bzl_file_name = "kconfig_flag_values.bzl"
    bzl_file_path = repo_ctx.path(bzl_file_name)

    repo_ctx.file(bzl_file_name)
    repo_ctx.file("BUILD.bazel")

    args = [
        repo_ctx.which("python3"),
        script_path,
        "--kconfig",
        str(repo_ctx.path(repo_ctx.attr.kconfig_file)),
        "gen_project",
        "--project",
        str(repo_ctx.path(repo_ctx.attr.conf_file)),
        "-o",
        bzl_file_path,
    ]
    result = repo_ctx.execute(args)
    if result.return_code != 0:
        fail("Failed to generate project BUILD file (%d):\n%s" % (result.return_code, result.stderr))
    repo_ctx.symlink(
        repo_ctx.attr.feature_cc_library,
        "feature_cc_library.bzl",
    )

gen_projectlib = repository_rule(
    implementation = _gen_projectlib_impl,
    attrs = {
        "kconfig_file": attr.label(
            allow_single_file = True,
            default = "//:kconfig.BUILD",
        ),
        "conf_file": attr.label(
            allow_single_file = True,
        ),
        "feature_cc_library": attr.label(
            allow_single_file = True,
            default = "//:feature_cc_library.bzl",
        ),
    },
)

def _libkconfig_impl(module_ctx):
    if len(module_ctx.modules) > 1:
        fail(
            msg = "libkconfig only supports a single module (for now)",
        )
    if len(module_ctx.modules[0].tags.kconfig_root) > 1:
        fail(
            msg = "libkconfig only supports a single kconfig root (for now)",
        )

    kconfig_file = module_ctx.modules[0].tags.kconfig_root[0].kconfig_file
    gen_kconfiglib(
        name = "kconfig",
        kconfig_file = kconfig_file,
    )

    for project in module_ctx.modules[0].tags.projects:
        for conf in project.prj_configs:
            project_name = module_ctx.path(conf).basename
            file_extension_index = project_name.rfind(".")
            if file_extension_index != -1:
                project_name = project_name[:file_extension_index]
            print("project.name: " + project_name)
            gen_projectlib(
                name = project_name,
                kconfig_file = kconfig_file,
                conf_file = conf,
            )

_libkconfig_root = tag_class(
    attrs = {
        "kconfig_file": attr.label(
            allow_single_file = True,
            default = "//:kconfig.BUILD",
        ),
    },
)

_libkconfig_projects = tag_class(
    attrs = {
        "prj_configs": attr.label_list(
            allow_empty = False,
            allow_files = True,
        ),
    },
)
libkconfig = module_extension(
    doc = "",
    implementation = _libkconfig_impl,
    tag_classes = {
        "kconfig_root": _libkconfig_root,
        "projects": _libkconfig_projects,
    },
)
