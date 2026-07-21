section FrappeConn;

// ----------------------------
// Public entrypoint (Navigator)
// ----------------------------
[DataSource.Kind="FrappeConn", Publish="FrappeConn.Publish"]
shared FrappeConn.Contents = (url as text) as table =>
    FrappeNavTable(url);

// Optional: keep Feed un-published (helper)
[DataSource.Kind="FrappeConn"]
shared FrappeConn.Feed = (url as text) as any =>
    FrappeConnImpl(url);

// TripPin Part 9
shared FrappeConn.TestConnection = (dataSourcePath as text) as list =>
    { "FrappeConn.Contents", dataSourcePath };
    
// Diagnostics (TripPin style) - load pqm as text and evaluate it
Diagnostics =
let
    diagText = Text.FromBinary(Extension.Contents("Diagnostics.pqm")),
    diagExpr = Expression.Evaluate(diagText, #shared)
in
    diagExpr;

LogValue   = Diagnostics[LogValue];
LogFailure = Diagnostics[LogFailure];

// ----------------------------
// Core HTTP + Auth
// ----------------------------
DefaultRequestHeaders = [
    #"Accept" = "application/json"
];

// Canonicalize URL to scheme://host[:port]/
NormalizeBaseUrl = (url as text) as text =>
let
    parts  = Uri.Parts(url),
    scheme = parts[Scheme],
    host   = parts[Host],
    port   = if Record.HasFields(parts, "Port") and parts[Port] <> null then ":" & Text.From(parts[Port]) else ""
in
    scheme & "://" & host & port & "/";

// DataSource Path (TripPin Part 4): stable credential scope per host
FrappeConnPath = (url as text) as text =>
let
    parts  = Uri.Parts(url),
    scheme = parts[Scheme],
    host   = parts[Host],
    port   = if Record.HasFields(parts, "Port") and parts[Port] <> null then ":" & Text.From(parts[Port]) else ""
in
    scheme & "://" & host & port;

GetAuthHeaders = () as record =>
let
    cred = Extension.CurrentCredential(),
    token =
        if cred = null then
            null
        else if Record.HasFields(cred, "Key") then
            Text.From(cred[Key])
        else if Record.HasFields(cred, "Password") then
            Text.From(cred[Password])
        else if Record.HasFields(cred, "ApiKey") then
            Text.From(cred[ApiKey])
        else
            null,

    authHeader = if token <> null then "token " & token else null,
    headers =
        if authHeader <> null
        then Record.AddField(DefaultRequestHeaders, "Authorization", authHeader)
        else DefaultRequestHeaders
in
    headers;

// ----------------------------
// Error message extractor
// ----------------------------

IsFrappeErrorPayload = (j as any) as logical =>
    j is record and (
        Record.HasFields(j, "exc")
        or Record.HasFields(j, "exception")
        or Record.HasFields(j, "_error_message")
        or Record.HasFields(j, "error")
    );

GetFrappeErrorMessage = (body as any) as text =>
let
    msg =
        if body = null then
            "No response body."
        else if body is record then
            if Record.HasFields(body, "exception") then Text.From(body[exception])
            else if Record.HasFields(body, "message") then Text.From(body[message])
            else if Record.HasFields(body, "_error_message") then Text.From(body[_error_message])
            else if Record.HasFields(body, "error") then
                let e = body[error]
                in if e is record and Record.HasFields(e, "message") then Text.From(e[message]) else Text.From(e)
            else
                "Frappe returned an error (no standard fields found)."
        else
            Text.From(body)
in
    msg;

// ----------------------------
// Generic JSON GET (RelativePath + Query) with Frappe exception as error
// ----------------------------
FrappeGetJson = (baseUrl as text, relativePath as text, optional query as nullable record) as any =>
let
    root    = NormalizeBaseUrl(baseUrl),
    headers = GetAuthHeaders(),

    // Diagnostics
    _root = LogValue("Frappe root", root),
    _path = LogValue("Frappe relativePath", relativePath),
    _qry  = LogValue("Frappe query", query),

    optionsBase =
        if query <> null then
            [
                Headers = headers,
                RelativePath = Text.TrimStart(relativePath, "/"),
                Query = query
            ]
        else
            [
                Headers = headers,
                RelativePath = Text.TrimStart(relativePath, "/")
            ],

    options =
        Record.Combine({
            optionsBase,
            [
                ManualCredentials = true,
                ManualStatusHandling = {400,401,403,404,409,417,422,429,500,501,502,503}
            ]
        }),

    // ✅ Log Web.Contents failures
    response =
        LogFailure(
            "Web.Contents failed",
            () => Web.Contents(root, options)
        ),

    meta_res = Value.Metadata(response),

    status =
        if Record.HasFields(meta_res, "Response.Status")
        then meta_res[#"Response.Status"]
        else 200,

    // ✅ Log Json.Document failures
    bodyJson =
        LogFailure(
            "Json.Document failed",
            () => Json.Document(response)
        ),

    // For non-json fallback (rare, but good to keep)
    bodyText = try Text.FromBinary(response) otherwise null,
    body     = if bodyJson <> null then bodyJson else bodyText,

    _status = LogValue("HTTP status", status),

    // 1) HTTP errors -> raise with Frappe message (if any)
    _http =
        if status >= 200 and status < 300 then
            null
        else
            error Error.Record(
                "FrappeConn",
                "HTTP " & Text.From(status) & " - " & GetFrappeErrorMessage(body),
                body
            ),

    // 2) Soft errors (HTTP 200 but Frappe exception payload)
    _soft =
        if bodyJson <> null and IsFrappeErrorPayload(bodyJson) then
            error Error.Record(
                "FrappeConn",
                "Frappe Error - " & GetFrappeErrorMessage(bodyJson),
                bodyJson
            )
        else
            null
in
    if bodyJson <> null then bodyJson else error Error.Record("FrappeConn", "Non-JSON response.", bodyText);

// Your old Feed can stay (returns raw JSON from base URL)
FrappeConnImpl = (url as text) as any =>
let
    root = NormalizeBaseUrl(url),
    raw  = Web.Contents(root, [Headers = GetAuthHeaders(), ManualCredentials = true]),
    json = Json.Document(raw)
in
    json;


// ----------------------------
// Dynamic discovery
// ----------------------------
GetDocTypes = (baseUrl as text) as table =>
let
    json = FrappeGetJson(
        baseUrl,
        "/api/method/pbi_integration.api.documents.get_doctypes",
        [
            fields   = "[""name"",""module"",""istable""]",
            order_by = "name"
        ]
    ),

    _ =
        if IsFrappeErrorPayload(json) then
            error Error.Record(
                "FrappeConn",
                "Frappe Error - " & GetFrappeErrorMessage(json),
                json
            )
        else if not Record.HasFields(json, "message") then
            error Error.Record(
                "FrappeConn",
                "DocType list did not return [message].",
                json
            )
        else
            null,

    // ✅ New API returns message as list directly — not json[data]
    rows = json[message],
    t0   = Table.FromRecords(rows),

    t1 = Table.TransformColumns(
        t0,
        {
            {"name",   each Text.From(_), type text},
            {"module", each try Text.From(_) otherwise null, type nullable text},
            {"istable", each
                let v = _
                in
                    if v is logical then v
                    else if v is number then v <> 0
                    else if v is text then (v = "1" or Text.Lower(v) = "true")
                    else false,
             type logical}
        }
    ),

    // ✅ No issingle in new API — removed that column and filter
    t2 = Table.AddColumn(
        t1,
        "module_norm",
        each
            let m = [module]
            in
                if m = null or Text.Trim(m) = "" then "Other"
                else Text.Trim(m),
        type text
    )
in
    t2;

// ----------------------------
// Schema helpers (TripPin 6 style)
// ----------------------------
EnforceSchema.Strict = 1;
EnforceSchema.IgnoreExtraColumns = 2;
EnforceSchema.IgnoreMissingColumns = 3;

CleanSchema = (schema as table) as table =>
let
    // force schema to have Name, Type columns (ignore extras)
    s0 = Table.SelectColumns(schema, {"Name","Type"}, MissingField.Error),

    // normalize Name to text
    s1 = Table.TransformColumns(s0, {{"Name", each Text.From(_), type text}}),

    // ✅ KEEP ONLY rows where [Type] is actually a PQ "type"
    s2 = Table.SelectRows(s1, each Value.Is([Type], type type)),

    // remove duplicates by Name (keep first)
    s3 = Table.Distinct(s2, {"Name"})
in
    s3;

SchemaTransformTable = (table as table, schema as table, optional enforceSchema as number) as table =>
let
    _enforceSchema = if (enforceSchema <> null) then enforceSchema else EnforceSchema.Strict,

    schemaClean = CleanSchema(schema),

    existing = Table.ColumnNames(table),

    schema2  = Table.SelectRows(schemaClean, each List.Contains(existing, [Name])),

    transforms =
        List.Transform(
            Table.ToRecords(schema2),
            each {
                _[Name],
                if Value.Is(_[Type], type type) then _[Type] else type any
            }
        ),

    typed =
        if List.IsEmpty(transforms) then
            table
        else
            Table.TransformColumnTypes(table, transforms),

    schemaNames = schemaClean[Name],

    addNames = List.RemoveItems(schemaNames, Table.ColumnNames(typed)),

    added =
        List.Accumulate(
            addNames,
            typed,
            (st, col) => Table.AddColumn(st, col, each null)
        ),

    fullList =
        if (_enforceSchema = EnforceSchema.Strict) then
            schemaNames
        else if (_enforceSchema = EnforceSchema.IgnoreMissingColumns) then
            Table.ColumnNames(added)
        else
            schemaNames & List.RemoveItems(Table.ColumnNames(added), schemaNames),

    reordered = Table.SelectColumns(added, fullList, MissingField.Ignore)
in
    reordered;

ValidateSchema = (schema as table, context as text) as table =>
let
    // Keep only Name + Type
    s0 = Table.SelectColumns(schema, {"Name","Type"}, MissingField.Error),

    // Normalize Name to text
    s1 = Table.TransformColumns(s0, {{"Name", each Text.From(_), type text}}),

    // Filter to only rows where Type is an M type value
    s2 = Table.SelectRows(
        s1,
        each
            [Name] <> null
            and Text.Trim([Name]) <> ""
            and Value.Is([Type], type type)   // ✅ correct check
    ),

    // If anything got dropped, show what was bad (this is the key to debugging)
    bad = Table.SelectRows(
        s1,
        each
            [Name] = null
            or Text.Trim(Text.From([Name])) = ""
            or not Value.Is([Type], type type)
    ),

    _ =
        if Table.RowCount(bad) > 0 then
            error Error.Record(
                "FrappeConn",
                "Invalid schema rows detected: " & context,
                bad
            )
        else
            null,

    cleaned = Table.Distinct(s2, {"Name"})
in
    cleaned;


// A simple mapping - you can expand later
FrappeFieldTypeToMType = (ft as nullable text) as type =>
let
    x = if ft = null then "" else Text.Lower(Text.Trim(ft)),
    t =
        if List.Contains({"int","integer"}, x) then Int64.Type
        else if List.Contains({"float","currency","percent"}, x) then type number
        else if List.Contains({"check","boolean"}, x) then type logical
        else if x = "date" then type date
        else if x = "datetime" then type datetime
        else if x = "time" then type time
        else type text
in
    t;

    NoValueFieldTypes = {
    "Section Break",
    "Column Break",
    "Tab Break",
    "HTML",
    "Table",
    "Table MultiSelect",
    "Button",
    "Image",
    "Fold",
    "Heading"
};

// Build schema from DocType metadata: /api/resource/DocType/<doctype>
GetDocTypeSchema = (baseUrl as text, doctype as text) as table =>
let
    metaJson =
        FrappeGetJson(
            baseUrl,
            "/api/method/pbi_integration.api.documents.get_doctype_meta",
            [ doctype = doctype ]
        ),

    // ✅ New API returns message as record directly — not json[data]
    metaRec = if metaJson is record then Record.FieldOrDefault(metaJson, "message", null) else null,
    fields  = if metaRec is record then Record.FieldOrDefault(metaRec, "fields", {}) else {},

    base = { {"name", type text} },

    dataFields =
        List.Select(
            fields,
            (f) =>
                f is record
                and Record.HasFields(f, "fieldname")
                and Record.HasFields(f, "fieldtype")
                and (try Text.Trim(Text.From(f[fieldname])) otherwise "") <> ""
                and not List.Contains(
                    NoValueFieldTypes,
                    try Text.Trim(Text.From(f[fieldtype])) otherwise ""
                )
        ),

    rows =
        base &
        List.RemoveNulls(
            List.Transform(
                dataFields,
                (f) =>
                    let
                        fname = try Text.Trim(Text.From(f[fieldname])) otherwise null,
                        ftype = try Text.From(f[fieldtype]) otherwise null
                    in
                        if fname = null or fname = "" then null
                        else { fname, FrappeFieldTypeToMType(ftype) }
            )
        ),

    schema = #table({"Name","Type"}, rows)
in
    schema;


GetDocTypePage =
(
    baseUrl as text,
    doctype as text,
    start as number,
    pageSize as number,
    optional columns as nullable list,
    optional orderBy as nullable text,
    optional filtersJson as nullable text
) as list =>
let
    // fields param: either explicit list or "*"
    fieldsParam =
        if columns <> null and List.Count(columns) > 0 then
            "[""" & Text.Combine(List.Transform(columns, each Text.From(_)), """,""") & """]"
        else
            "[""*""]",

    query0 = [
        limit_start = Text.From(Number.RoundDown(start)),
        limit_page_length = Text.From(Number.RoundDown(pageSize)),
        fields = fieldsParam
    ],

    query1 =
        if orderBy <> null and Text.Trim(orderBy) <> "" then
            Record.AddField(query0, "order_by", orderBy)
        else
            query0,

    query2 =
        if filtersJson <> null and Text.Trim(filtersJson) <> "" then
            Record.AddField(query1, "filters", filtersJson)
        else
            query1,

    json =
        FrappeGetJson(
            baseUrl,
            "/api/resource/" & Uri.EscapeDataString(doctype),
            query2
        ),

    isSoftError =
        (json is record) and IsFrappeErrorPayload(json),

    _soft =
        if isSoftError then
            error Error.Record(
                "FrappeConn",
                "You don't have access to DocType: " & doctype,
                GetFrappeErrorMessage(json)
            )
        else
            null,

    rows =
        if json is record then
            Record.FieldOrDefault(json, "data", {})
        else
            {}
in
    rows;

GetDocTypeCount =
(
    baseUrl as text,
    doctype as text,
    optional filtersJson as nullable text
) as number =>
let
    query0 = [
        limit_start = "0",
        limit_page_length = "1",
        fields = "[""name""]"
    ],

    query1 =
        if filtersJson <> null and Text.Trim(filtersJson) <> "" then
            Record.AddField(query0, "filters", filtersJson)
        else
            query0,

    j =
        FrappeGetJson(
            baseUrl,
            "/api/resource/" & Uri.EscapeDataString(doctype),
            query1
        ),

    count =
        if (j is record) and Record.HasFields(j, "total_count") then
            Number.From(j[total_count])

        else if (j is record) and Record.HasFields(j, "count") then
            Number.From(j[count])

        else
            -1
in
    count;

TableTypeFromSchema = (schema as table, optional cols as nullable list) as type =>
let
    s = if cols = null then schema
        else Table.SelectRows(schema, each List.Contains(cols, [Name])),

    names = List.Transform(s[Name], each Text.From(_)),
    types = List.Transform(s[Type], each if Value.Is(_, type type) then _ else type any),

    // Build an empty table, then stamp the record type onto it
    emptyTable  = Table.FromRows({}, names),
    fieldsRecord = Record.FromList(types, names),
    rowType      = Type.ForRecord(fieldsRecord, false),
    typedTable   = Value.ReplaceType(emptyTable, type table (rowType)),
    tableType    = Value.Type(typedTable)
in
    tableType;


SortToOrderBy = (sort as list) as nullable text =>
let
    parts =
        List.Transform(
            sort,
            (s) =>
                let
                    col = Record.FieldOrDefault(s, "Name", null),
                    ord = Record.FieldOrDefault(s, "Order", null),
                    dir =
                        if ord = Order.Descending or ord = 1 or Text.From(ord) = "Descending" then
                            "desc"
                        else
                            "asc"
                in
                    if col = null then null else col & " " & dir
        ),
    clean = List.RemoveNulls(parts)
in
    if List.IsEmpty(clean) then null else Text.Combine(clean, ", ");

GetAstKind = (x as any) as nullable text =>
    if x is record then Record.FieldOrDefault(x, "Kind", null) else null;

GetAstOperator = (x as any) as nullable text =>
    if x is record then Record.FieldOrDefault(x, "Operator", null) else null;

IsRowRef = (x as any) as logical =>
    x is record
    and GetAstKind(x) = "Invocation"
    and Record.HasFields(x, "Name")
    and x[Name] = "RowExpression.Row";

TryGetFieldName = (x as any) as nullable text =>
    if x is record and GetAstKind(x) = "FieldAccess" then
        Record.FieldOrDefault(x, "MemberName", null)
    else
        null;

TryGetConstantValue = (x as any) as any =>
    if x is record and GetAstKind(x) = "Constant" then
        Record.FieldOrDefault(x, "Value", null)
    else
        null;

MapAstOperator = (op as nullable text) as nullable text =>
    if op = "Equals" then "="
    else if op = "NotEquals" then "!="
    else if op = "GreaterThan" then ">"
    else if op = "GreaterThanOrEquals" then ">="
    else if op = "LessThan" then "<"
    else if op = "LessThanOrEquals" then "<="
    else if op = "Like" then "like"
    else if op = "NotLike" then "not like"
    else null;

// Returns {column, operator, value} for simple binary comparisons like [name] = "Cash"
TryParseBinaryComparison = (node as any) as nullable list =>
let
    kind = GetAstKind(node),
    op0  = GetAstOperator(node),

    left  = if node is record then Record.FieldOrDefault(node, "Left", null) else null,
    right = if node is record then Record.FieldOrDefault(node, "Right", null) else null,

    leftField  = TryGetFieldName(left),
    rightField = TryGetFieldName(right),

    leftVal  = TryGetConstantValue(left),
    rightVal = TryGetConstantValue(right),

    op = MapAstOperator(op0),

    out =
        if kind = "Binary" and op <> null and leftField <> null and rightVal <> null then
            { leftField, op, rightVal }
        else if kind = "Binary" and op <> null and rightField <> null and leftVal <> null then
            { rightField, op, leftVal }
        else
            null
in
    out;

IsNullValue = (v as any) as logical =>
    v = null;

IsBlankTextValue = (v as any) as logical =>
    v is text and v = "";

IsNullOrBlank = (v as any) as logical =>
    IsNullValue(v) or IsBlankTextValue(v);

// Flatten OR chains
CollectOrClauses = (node as any) as list =>
let
    kind = GetAstKind(node),
    op   = GetAstOperator(node)
in
    if kind = "Binary" and op = "Or" then
        List.Combine({
            @CollectOrClauses(node[Left]),
            @CollectOrClauses(node[Right])
        })
    else
        let c = TryParseBinaryComparison(node) in if c = null then {} else { c };

// Flatten AND chains
CollectAndNodes = (node as any) as list =>
let
    kind = GetAstKind(node),
    op   = GetAstOperator(node)
in
    if kind = "Binary" and op = "And" then
        List.Combine({
            @CollectAndNodes(node[Left]),
            @CollectAndNodes(node[Right])
        })
    else
        { node };

// Collapse OR of equals/not-equals on same column into in/not in
TryCollapseOrNode = (node as any) as nullable list =>
let
    clauses = CollectOrClauses(node),

    valid =
        List.Count(clauses) > 1 and
        List.AllTrue(
            List.Transform(clauses, each List.Count(_) = 3 and (_{1} = "=" or _{1} = "!="))
        ),

    cols = if valid then List.Distinct(List.Transform(clauses, each _{0})) else {},
    ops  = if valid then List.Distinct(List.Transform(clauses, each _{1})) else {},

    out =
        if valid and List.Count(cols) = 1 and List.Count(ops) = 1 then
            { cols{0}, if ops{0} = "=" then "in" else "not in", List.Transform(clauses, each _{2}) }
        else
            null
in
    out;

// Collapse AND of != on same column into not in
TryCollapseAndNode = (node as any) as nullable list =>
let
    nodes = CollectAndNodes(node),

    clauses =
        List.RemoveNulls(
            List.Transform(nodes, each TryParseBinaryComparison(_))
        ),

    valid =
        List.Count(clauses) > 1 and
        List.AllTrue(
            List.Transform(clauses, each List.Count(_) = 3 and _{1} = "!=")
        ),

    cols = if valid then List.Distinct(List.Transform(clauses, each _{0})) else {},

    out =
        if valid and List.Count(cols) = 1 then
            { cols{0}, "not in", List.Transform(clauses, each _{2}) }
        else
            null
in
    out;

TryCollapseNullBlankNode = (node as any) as nullable list =>
let
    kind = GetAstKind(node),
    op   = GetAstOperator(node),

    out =
        if kind = "Binary" and op = "And" then
            let
                nodes =
                    CollectAndNodes(node),

                clauses =
                    List.RemoveNulls(
                        List.Transform(nodes, each TryParseBinaryComparison(_))
                    ),

                valid =
                    List.Count(clauses) >= 1 and
                    List.AllTrue(
                        List.Transform(
                            clauses,
                            each List.Count(_) = 3 and _{1} = "!=" and IsNullOrBlank(_{2})
                        )
                    ),

                cols =
                    if valid then
                        List.Distinct(List.Transform(clauses, each _{0}))
                    else
                        {}
            in
                if valid and List.Count(cols) = 1 then
                    { cols{0}, "is", "set" }
                else
                    null

        else if kind = "Binary" and op = "Or" then
            let
                clauses =
                    CollectOrClauses(node),

                valid =
                    List.Count(clauses) >= 1 and
                    List.AllTrue(
                        List.Transform(
                            clauses,
                            each List.Count(_) = 3 and _{1} = "=" and IsNullOrBlank(_{2})
                        )
                    ),

                cols =
                    if valid then
                        List.Distinct(List.Transform(clauses, each _{0}))
                    else
                        {}
            in
                if valid and List.Count(cols) = 1 then
                    { cols{0}, "is", "not set" }
                else
                    null

        else
            null
in
    out;

CollectClauses = (node as any) as list =>
let
    kind = GetAstKind(node),
    op   = GetAstOperator(node),

    nullBlankCollapsed = TryCollapseNullBlankNode(node),

    out =
        if nullBlankCollapsed <> null then
            { nullBlankCollapsed }

        else if kind = "Binary" and op = "And" then
            let
                collapsed = TryCollapseAndNode(node)
            in
                if collapsed <> null then
                    { collapsed }
                else
                    List.Combine({
                        @CollectClauses(node[Left]),
                        @CollectClauses(node[Right])
                    })

        else if kind = "Binary" and op = "Or" then
            let
                collapsed = TryCollapseOrNode(node)
            in
                if collapsed <> null then
                    { collapsed }
                else
                    {}

        else
            let
                c = TryParseBinaryComparison(node)
            in
                if c = null then {} else { c }
in
    out;

FiltersToFrappeJson = (doctype as text, ast as any) as nullable text =>
let
    clauses = CollectClauses(ast),
    frappe  = List.Transform(clauses, each { doctype, _{0}, _{1}, _{2} }),
    txt     = if List.IsEmpty(frappe) then null else Text.FromBinary(Json.FromValue(frappe))
in
    txt;

// ----------------------------
GetDocTypeTable = (baseUrl as text, doctype as text) as table =>
let
    fetchPageSize = 1000,

    // 1) Schema
    schemaTry = try GetDocTypeSchema(baseUrl, doctype),
    schema0 =
        if schemaTry[HasError] then
            #table({"Name","Type"}, {{"name", type text}})
        else
            schemaTry[Value],

    schema = ValidateSchema(schema0, "GetDocTypeSchema(" & doctype & ")"),

    RecordsToTable = (rows as list, optional cols as nullable list) as table =>
    let
        effectiveSchema =
            if cols <> null and List.Count(cols) > 0 then
                Table.SelectRows(schema, each List.Contains(cols, [Name]))
            else
                schema,

        t0 =
            if List.IsEmpty(rows) then
                Table.FromRows({}, effectiveSchema[Name])
            else
                Table.FromRecords(rows),

        t1 = SchemaTransformTable(t0, effectiveSchema, EnforceSchema.IgnoreExtraColumns)
    in
        t1,

    baseTable = SchemaTransformTable(
                Table.FromRows({}, List.Transform(schema[Name], each Text.From(_))),
                schema,
                EnforceSchema.IgnoreExtraColumns
            ),

    // 3) General fetch
   Fetch =
    (
        skip as number,
        take as nullable number,
        optional cols as nullable list,
        optional orderBy as nullable text,
        optional filtersJson as nullable text
    )
    as table =>
let
    out =
        if take = null then
            RecordsToTable(
                GetDocTypePage(baseUrl, doctype, skip, 0, cols, orderBy, filtersJson)
            )
        else
            let
                takeEff =
                    if take <= 0 then
                        fetchPageSize
                    else
                        take,

                pageCount = Number.RoundUp(takeEff / fetchPageSize),

                pages =
                    List.Transform(
                        {0 .. pageCount - 1},
                        (i) =>
                            let
                                start = skip + (i * fetchPageSize),
                                len   = List.Min({fetchPageSize, takeEff - (i * fetchPageSize)})
                            in
                                if len <= 0 then
                                    {}
                                else
                                    GetDocTypePage(baseUrl, doctype, start, len, cols, orderBy, filtersJson)
                    ),

                allRows = List.Combine(pages)
            in
                RecordsToTable(allRows)
in
    out,

    // 4) View factory
    View = (state as record) as table =>
        Table.View(
            null,
            [
                GetType = () as type =>
    let
        cols0 = Record.FieldOrDefault(state, "Columns", null),
        cols =
            if cols0 is list and List.Count(cols0) > 0 then
                List.Intersect({cols0, schema[Name]})
            else
                schema[Name],

        filtered = Table.SelectRows(schema, each List.Contains(cols, [Name])),
        empty    = Table.FromRows({}, List.Transform(filtered[Name], each Text.From(_))),
        typed    = SchemaTransformTable(empty, filtered, EnforceSchema.Strict)
    in
        Value.Type(typed),
                GetRows = () as table =>
    let
        skip        = Number.From(Record.FieldOrDefault(state, "Skip", 0)),
        rawTake     = Record.FieldOrDefault(state, "Take", null),

        cols0       = Record.FieldOrDefault(state, "Columns", null),
        orderBy     = Record.FieldOrDefault(state, "OrderBy", null),
        filtersJson = Record.FieldOrDefault(state, "Filters", null),
        localCond   = Record.FieldOrDefault(state, "LocalRowFilter", null),

        cols =
            if cols0 is list and List.Count(cols0) > 0 then
                List.Intersect({cols0, schema[Name]})
            else
                null,

        out0 =
    Fetch(
        skip,
        if rawTake = null then null else Number.From(rawTake),
        cols,
        orderBy,
        filtersJson
    ),

        out1 =
            if cols <> null then
                Table.SelectColumns(out0, cols, MissingField.Ignore)
            else
                out0,

        out2 =
            if localCond <> null then
                Table.SelectRows(out1, localCond)
            else
                out1,
                
    cols1 = Record.FieldOrDefault(state, "Columns", null),
    finalCols =
    if cols1 is list and List.Count(cols1) > 0 then
        List.Intersect({cols1, schema[Name]})
    else
        schema[Name],

    out3 = SchemaTransformTable(out2, 
        Table.SelectRows(schema, each List.Contains(finalCols, [Name])),
        EnforceSchema.Strict)
in
    out3,

        GetRowCount = () as number =>
    let
        filtersJson = Record.FieldOrDefault(state, "Filters", null),
        count = GetDocTypeCount(baseUrl, doctype)
    in
        count,

                OnTake = (count as number) as table => @View(state & [Take = count]),
                OnSkip = (count as number) as table => @View(state & [Skip = count]),
                OnSort = (sort as list) as table =>
        @View(state & [OrderBy = SortToOrderBy(sort)]),

                OnSelectColumns = (cols as list) as table =>
    let
        allowed0 = List.Intersect({cols, schema[Name]}),
        allowed =
            if List.Count(allowed0) = 0 then
                null
            else if List.Count(allowed0) = List.Count(schema[Name]) then
                null
            else
                allowed0
    in
        @View(state & [Columns = allowed]),

OnSelectRows = (condition as function) as table =>
    let
        ast = RowExpression.From(condition),
        fj  = FiltersToFrappeJson(doctype, ast)
    in
        if fj = null then
            error Error.Record(
                "FrappeConn",
                "Could not translate row filter to Frappe filters.",
                ast
            )
        else
            @View(state & [Filters = fj])
            ]
        ),
    out = View([Skip = 0, Take = null])
in
    out;
    
// ----------------------------
// Navigation helper (no keys)
// ----------------------------
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
let
    navType =
        Value.Type(table) meta
        [
            NavigationTable.NameColumn = nameColumn,
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn,
            NavigationTable.ItemNameColumn = itemNameColumn,
            NavigationTable.IsLeafColumn = isLeafColumn,

            // ✅ keeps the UI as table, but delays preview evaluation
            Preview.DelayColumn = dataColumn
        ],
    navTable = Value.ReplaceType(table, navType)
in
    navTable;

// ----------------------------
// Flat Navigator (DocTypes as leaf tables)
// ----------------------------
FrappeNavTable = (url as text) as table =>
let
    baseUrl  = Text.From(url),
    docTypes = GetDocTypes(baseUrl),
    namesOnly = Table.Distinct(Table.SelectColumns(docTypes, {"name"})),

    // ✅ Data is a function that returns a table
    withData =
        Table.AddColumn(
            namesOnly,
            "Data",
            each () => GetDocTypeTable(baseUrl, [name]),
            type function
        ),

    withKind   = Table.AddColumn(withData, "ItemKind", each "Table", type text),
    withItemNm = Table.AddColumn(withKind, "ItemName", each "Table", type text),
    withLeaf   = Table.AddColumn(withItemNm, "IsLeaf", each true, type logical),

    nav = Table.ToNavigationTable(withLeaf, {"name"}, "name", "Data", "ItemKind", "ItemName", "IsLeaf")
in
    nav;

// ----------------------------
// Data Source Kind & Publish
// ----------------------------
FrappeConn = [
    Authentication = [
        Key = []
    ],
    Label = "Frappe - Token Authentication (Dynamic Navigator)",

    // ✅ TripPin Part 4
    DataSource.Path = FrappeConnPath,

    // ✅ TripPin Part 9
    TestConnection = (dataSourcePath) => { "FrappeConn.Contents", dataSourcePath }
];

FrappeConn.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { "Frappe Documents", "Frappe Documents" }
];