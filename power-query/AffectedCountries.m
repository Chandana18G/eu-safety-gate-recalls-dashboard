// AffectedCountries: one row per (alert, other country where the vehicle was also found).
// The export lists them comma-separated, e.g. "Germany, Finland, The Netherlands".
let
    Source = Recall,
    Pairs = Table.SelectColumns(Source, {"Alert_Number", "Also_Affected"}),
    NonEmpty = Table.SelectRows(Pairs, each [Also_Affected] <> null and [Also_Affected] <> ""),
    Split = Table.ExpandListColumn(
        Table.TransformColumns(NonEmpty, {{"Also_Affected", each List.Transform(Text.Split(_, ","), Text.Trim)}}),
        "Also_Affected"),
    Renamed = Table.RenameColumns(Split, {{"Also_Affected", "Affected Country"}}),
    Clean = Table.SelectRows(Renamed, each [Affected Country] <> ""),
    // Remove duplicates per alert only, so every alert keeps its own list of countries.
    Distinct = Table.Distinct(Clean, {"Alert_Number", "Affected Country"}),
    Typed = Table.TransformColumnTypes(Distinct, {{"Affected Country", type text}})
in
    Typed
