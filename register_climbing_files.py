#!/usr/bin/env python3
"""Registra os arquivos novos de escalada no project.pbxproj do target iOS."""
import sys

PBX = "HealthFit/HealthFit/HealthFit.xcodeproj/project.pbxproj"

# (arquivo, grupo de destino, arquivo vizinho já existente nesse grupo)
FILES = [
    ("ClimbingModels.swift", "Models", "RowingModels.swift"),
    ("ClimbingGearModels.swift", "Models", "RowingModels.swift"),
    ("ClimbingAnalytics.swift", "Services", "RowingMetricsService.swift"),
    ("ClimbingMotionService.swift", "Services", "RowingMetricsService.swift"),
    ("ClimbingWeatherService.swift", "Services", "RowingMetricsService.swift"),
    ("ClimbingGearService.swift", "Services", "RowingMetricsService.swift"),
    ("ClimbingAssistantEngine.swift", "Services", "RowingMetricsService.swift"),
    ("ClimbingAreaCatalog.swift", "Services", "RowingMetricsService.swift"),
    ("ClimbingMapView.swift", "Workout", "RunRouteMapView.swift"),
    ("ClimbingLogbookView.swift", "Workout", "RunRouteMapView.swift"),
    ("ClimbingAttemptEditorView.swift", "Workout", "RunRouteMapView.swift"),
    ("FightModels.swift", "Models", "RowingModels.swift"),
    ("FightHubView.swift", "Workout", "RunRouteMapView.swift"),
]

src = open(PBX).read()

assigned = []
for index, (name, group, anchor) in enumerate(FILES):
    file_ref = "F10009%02d" % (index + 1)
    build_ref = "B10009%02d" % (index + 1)
    if "path = %s;" % name in src:
        continue
    if file_ref in src or build_ref in src:
        sys.exit("ID já em uso: %s" % file_ref)
    assigned.append((name, group, anchor, file_ref, build_ref))

if not assigned:
    sys.exit("Nada a registrar.")

# 1) PBXBuildFile + 2) PBXFileReference: inseridos logo após o marcador da seção.
build_lines = "".join(
    "\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };\n"
    % (build_ref, name, file_ref, name)
    for name, _, _, file_ref, build_ref in assigned
)
src = src.replace(
    "/* Begin PBXBuildFile section */\n",
    "/* Begin PBXBuildFile section */\n" + build_lines,
    1,
)

ref_lines = "".join(
    '\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = %s; sourceTree = "<group>"; };\n'
    % (file_ref, name, name)
    for name, _, _, file_ref, _ in assigned
)
src = src.replace(
    "/* Begin PBXFileReference section */\n",
    "/* Begin PBXFileReference section */\n" + ref_lines,
    1,
)


def insert_after_anchor(text, anchor_name, new_line, occurrence_filter):
    """Insere new_line logo após a linha do vizinho que satisfaz occurrence_filter."""
    lines = text.split("\n")
    for i, line in enumerate(lines):
        if anchor_name in line and occurrence_filter(line):
            lines.insert(i + 1, new_line)
            return "\n".join(lines)
    sys.exit("Âncora não encontrada: %s" % anchor_name)


# 3) children do grupo: ancora na linha do vizinho dentro da lista de children.
for name, group, anchor, file_ref, _ in assigned:
    src = insert_after_anchor(
        src,
        anchor,
        "\t\t\t\t%s /* %s */," % (file_ref, name),
        lambda line: line.strip().startswith("F") and line.strip().endswith("*/,"),
    )

# 4) Sources build phase: ancora na entrada do vizinho.
for name, group, anchor, _, build_ref in assigned:
    src = insert_after_anchor(
        src,
        "%s in Sources */," % anchor,
        "\t\t\t\t%s /* %s in Sources */," % (build_ref, name),
        lambda line: line.strip().startswith("B"),
    )

open(PBX, "w").write(src)
print("Registrados %d arquivos:" % len(assigned))
for name, group, _, file_ref, build_ref in assigned:
    print("  %-32s %-9s %s / %s" % (name, group, file_ref, build_ref))
