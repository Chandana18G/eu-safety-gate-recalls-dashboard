// Recall: one row per Safety Gate alert for motor vehicles.
// Source: the EU Safety Gate "search list" export (Excel). Change DataFile to where the
// workbook is on your machine.
let
    DataFile = "C:\Users\Chandana G\eu-safety-gate-recalls-dashboard\data\safety_gate_motor_vehicles_2026-08-02.xlsx",
    Source = Excel.Workbook(File.Contents(DataFile), null, true),
    Sheet = Source{[Item = "Weekly Reports", Kind = "Sheet"]}[Data],

    // The export starts with a title row and a note row; the third row holds the column names.
    Headers = Table.PromoteHeaders(Table.Skip(Sheet, 2), [PromoteAllScalars = true]),
    Alerts = Table.SelectRows(Headers, each [Alert number] <> null and Text.Trim(Text.From([Alert number])) <> ""),

    // Keep the columns the report uses. In the export, "Risk legal provision" holds the
    // defect description and "Product" the vehicle type.
    Renamed = Table.RenameColumns(
        Table.SelectColumns(Alerts, {
            "Type of alert", "Type", "Alert number", "Alert submitted by", "Country of origin",
            "Risk type", "Risk legal provision", "Product", "Name", "Brand",
            "Type / number of model", "Products were found and measures were taken also in", "URL of Case"}),
        {
            {"Type of alert", "Risk Level"}, {"Type", "Notifier"}, {"Alert number", "Alert_Number"},
            {"Alert submitted by", "Notifying Country"}, {"Country of origin", "Origin Country"},
            {"Risk type", "Hazard"}, {"Risk legal provision", "Defect Description"},
            {"Product", "Vehicle Type"}, {"Name", "Model"}, {"Type / number of model", "Model Type"},
            {"Products were found and measures were taken also in", "Also_Affected"}, {"URL of Case", "Case URL"}}),
    Typed = Table.TransformColumnTypes(Renamed, List.Transform(Table.ColumnNames(Renamed), each {_, type text})),
    Trimmed = Table.TransformColumns(Typed, List.Transform(Table.ColumnNames(Typed), each {_, (t) => if t = null then null else Text.Trim(t), type text})),

    // Alert numbers look like "A12/0028/17": the last part is the year.
    WithYear = Table.AddColumn(Trimmed, "Year", each 2000 + Number.FromText(List.Last(Text.Split([Alert_Number], "/"))), Int64.Type),

    // Brand: first brand of multi-brand alerts, with whole-value spelling fixes
    // (whole values only - a text replace of "Man" would also change "Mann+Hummel").
    MultiBrand = Table.AddColumn(WithYear, "Multi-Brand Alert", each if Text.Contains([Brand] ?? "", ",") then "Yes" else "No", type text),
    FirstBrand = Table.TransformColumns(MultiBrand, {{"Brand", each Text.Trim(Text.BeforeDelimiter(_ ?? "", ",")), type text}}),
    BrandFixes = {{"Bmw", "BMW"}, {"Vw", "VW"}, {"Ktm", "KTM"}, {"Daf", "DAF"}, {"Man", "MAN"},
                  {"AUDI", "Audi"}, {"CITROEN", "Citroen"}, {"NEW HOLLAND", "New Holland"}, {"VOLVO TRUCKS", "Volvo Trucks"},
                  // one alert lists the brand as a numbered list; Range Rover is a Land Rover model
                  {"1. Land Rover 2. Range Rover", "Land Rover"},
                  // 12 alerts have no brand in the export
                  {"", "Not specified"}},
    Brands = List.Accumulate(BrandFixes, FirstBrand, (t, fix) => Table.ReplaceValue(t, fix{0}, fix{1}, Replacer.ReplaceValue, {"Brand"})),

    // Case-insensitive "does the text mention any of these words?"
    Mentions = (text as nullable text, words as list) as logical =>
        text <> null and List.AnyTrue(List.Transform(words, (w) => Text.Contains(text, w, Comparer.OrdinalIgnoreCase))),

    // Vehicle category. Order matters: parts first, campers before vans ("Camper van").
    Category = Table.AddColumn(Brands, "Vehicle category", each
        let v = [Vehicle Type] in
        if Mentions(v, {"tyre", "tire", "part", "component", "helmet"}) then "Component / Part"
        else if Mentions(v, {"passenger car"}) then "Passenger car"
        else if Mentions(v, {"camper", "motorhome", "mobile home", "caravan"}) then "Camper / Motorhome"
        else if Mentions(v, {"motorcycle", "scooter", "moped", "bicycle", "three-wheel"}) then "Two-Wheeler"
        else if Mentions(v, {"van", "light commercial", "pickup", "pick-up", "utility"}) then "Van / LCV"
        else if Mentions(v, {"lorry", "truck", "heavy goods"}) then "Truck / Lorry"
        else if Mentions(v, {"bus", "coach"}) then "Bus / Coach"
        else if Mentions(v, {"tractor", "terrain", "atv", "quad"}) then "Agricultural / ATV"
        else if Mentions(v, {"trailer"}) then "Trailer"
        else "Other", type text),

    // Defective component, from keywords in the defect description (first match wins).
    Component = Table.AddColumn(Category, "Component", each
        let d = [Defect Description] in
        if d = null or d = "" then "Not classified (no description)"
        else if Mentions(d, {"airbag", "seat belt", "seatbelt"}) then "Airbag / Restraints"
        else if Mentions(d, {"brak"}) then "Braking / ESP"
        else if Mentions(d, {"steer"}) then "Steering"
        else if Mentions(d, {"fuel"}) then "Fuel System"
        else if Mentions(d, {"batter", "high-voltage", "high voltage"}) then "Battery / HV"
        else if Mentions(d, {"electr", "software", "wiring"}) then "Electrical / Software"
        else if Mentions(d, {"wheel", "suspension", "bearing", "axle"}) then "Wheels / Suspension"
        else if Mentions(d, {"engine", "transmission", "gearbox"}) then "Engine / Powertrain"
        else if Mentions(d, {"roof", "door", "window", "mirror"}) then "Body / Interior"
        else "Other (unmatched)", type text),

    // "Has Description 2" is kept identical to "Has Description" for report compatibility.
    HasDescription = Table.AddColumn(Component, "Has Description", each if [Defect Description] = null or [Defect Description] = "" then "No" else "Yes", type text),
    HasDescription2 = Table.AddColumn(HasDescription, "Has Description 2", each [Has Description], type text),
    PrimaryHazard = Table.AddColumn(HasDescription2, "Primary Hazard", each Text.Trim(Text.BeforeDelimiter([Hazard] ?? "", ",")), type text)
in
    PrimaryHazard
