section FrappeReports;

NormalizeUrlScheme = (u as text) as text =>
let
    CleanedUrl = Text.TrimEnd(Text.Trim(u), "/"),
    
    // Add https:// 
    UrlWithProtocol = if not Text.StartsWith(CleanedUrl, "http://") and not Text.StartsWith(CleanedUrl, "https://")
                      then "https://" & CleanedUrl
                      else CleanedUrl,
    

    FinalUrl = Text.Replace(UrlWithProtocol, "http://", "https://")
in
    FinalUrl;

[DataSource.Kind="FrappeReports", Publish="FrappeReports.Publish"]
shared FrappeReports.Contents = Value.ReplaceType(
    (url as text, optional filtersJson as nullable text) =>
        let
            // Normalize URL at entry point before any other processing
            normalizedUrl = NormalizeUrlScheme(url),
            filters = if filtersJson = null or Text.Trim(filtersJson) = "" then "{}" else filtersJson
        in
            FrappeReportsNavTable(normalizedUrl, filters),
    type function (
        url as (Uri.Type meta [
            Documentation.FieldCaption = "Frappe Site URL",
            Documentation.FieldDescription = "Enter the URL of your Frappe site (e.g. https://erp.yourinstance.com).",
            Documentation.SampleValues = {"https://erp.yourinstance.com"}
        ]),
        optional filtersJson as (type nullable text meta [
        Documentation.FieldCaption = "Filters (JSON/M Record)",
        Documentation.FieldDescription = "Enter filters as JSON e.g. {""company"":""J. Y. Foods""} or M record e.g. [company = ""J. Y. Foods""]",
        Documentation.SampleValues = {"[company = ""Sample Company""]"},
        Formatting.IsMultiLine = true,
        Formatting.IsCode = true
        ])
    ) as table meta [
        Documentation.Name = "Frappe Reports",
        Documentation.LongDescription = "Connect to Frappe Framework reports"
    ]
);

[DataSource.Kind="FrappeReports"]
shared FrappeReports.Feed = Value.ReplaceType(
    (url as text) as any => FrappeReportsImpl(NormalizeUrlScheme(url)),
    type function (
        url as (Uri.Type meta [
            Documentation.FieldCaption = "Frappe Site URL",
            Documentation.FieldDescription = "Enter the URL of your Frappe site (e.g. https://erp.yourinstance.com).",
            Documentation.SampleValues = {"https://erp.yourinstance.com", "erp.yourinstance.com"}
        ])
    ) as any
);

shared FrappeReports.TestConnection = (dataSourcePath as text) as list =>
    { "FrappeReports.Contents", dataSourcePath };


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


GetAuthHeaders = () as record =>
let
    cred = Extension.CurrentCredential(),
    authHeader =
        if cred = null then
            null
        else if Record.HasFields(cred, "AuthenticationKind") and cred[AuthenticationKind] = "OAuth" then
            "Bearer " & cred[access_token]
        else if Record.HasFields(cred, "Key") then
            "token " & Text.From(cred[Key])
        else if Record.HasFields(cred, "Password") then
            "token " & Text.From(cred[Password])
        else if Record.HasFields(cred, "ApiKey") then
            "token " & Text.From(cred[ApiKey])
        else
            null,

    headers =
        if authHeader <> null
        then Record.AddField(DefaultRequestHeaders, "Authorization", authHeader)
        else DefaultRequestHeaders
in
    headers;

// ----------------------------
// OAuth 2.0 (Authorization Code + PKCE)
// ----------------------------
oauth_scope  = "all";
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html"; // required by Power BI

windowWidth  = 800;
windowHeight = 1200;

Base64UrlEncode = (raw as binary) as text =>
let
    base64    = Binary.ToText(raw, BinaryEncoding.Base64),
    urlSafe   = Text.Replace(Text.Replace(base64, "+", "-"), "/", "_"),
    noPadding = Text.TrimEnd(urlSafe, "=")
in
    noPadding;

GetClientId = (root as text) as text =>
    Json.Document(Web.Contents(root & "/api/method/pbi_integration.api.settings.get_oauth_client_id", [ManualCredentials = true]))[message];


EscapeForQuery = (v as text) as text =>
    Text.Replace(Uri.EscapeDataString(v), "|", "%7C");


StartLogin = (resourceUrl as text, state, display) =>
let
    root          = NormalizeUrlScheme(resourceUrl),
    codeVerifier  = Text.NewGuid() & Text.NewGuid(),
    codeChallenge = Base64UrlEncode(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(codeVerifier))),
    AuthorizeUrl  = root & "/api/method/frappe.integrations.oauth2.authorize?"
        & "client_id="             & EscapeForQuery(GetClientId(root))
        & "&response_type=code"
        & "&scope="                & EscapeForQuery(oauth_scope)
        & "&state="                & EscapeForQuery(state)          // required in Power BI Service - don't drop this
        & "&redirect_uri="         & EscapeForQuery(redirect_uri)
        & "&code_challenge_method=S256"
        & "&code_challenge="       & EscapeForQuery(codeChallenge)
in
    [
        LoginUri     = AuthorizeUrl,
        CallbackUri  = redirect_uri,
        WindowHeight = windowHeight,
        WindowWidth  = windowWidth,
        Context      = codeVerifier & "|" & root   // round-tripped to FinishLogin, already normalized
    ];

FinishLogin = (context, callbackUri, state) =>
let
    ctxParts = Text.Split(context, "|"),
    verifier = ctxParts{0},
    root     = ctxParts{1},
    Parts    = Uri.Parts(callbackUri)[Query]
in
    if (Parts[error]? <> null) then
        error Error.Record(Parts[error], Parts[error_description]?)
    else
        TokenMethod(root, Parts[code], "authorization_code", verifier);

TokenMethod = (root as text, code, grant_type, optional verifier) =>
let
    codeVerifierPart = if (verifier <> null) then "&code_verifier=" & EscapeForQuery(verifier) else "",
    codeParameter    = if (grant_type = "authorization_code") then "&code=" & EscapeForQuery(code) else "&refresh_token=" & EscapeForQuery(code),
    body = "client_id="    & EscapeForQuery(GetClientId(root))
        & "&grant_type="   & EscapeForQuery(grant_type)
        & "&redirect_uri=" & EscapeForQuery(redirect_uri)
        & codeParameter
        & codeVerifierPart,
    Response = Web.Contents(root & "/api/method/frappe.integrations.oauth2.get_token", [
        Content = Text.ToBinary(body),
        Headers = [
            #"Content-type" = "application/x-www-form-urlencoded",
            #"Accept" = "application/json"
        ],
        ManualStatusHandling = {400, 401}
    ]),
    Parts = Json.Document(Response)
in
    if (Parts[error]? <> null) then
        error Error.Record(Parts[error], Parts[message]?)
    else
        Parts;

Refresh = (resourceUrl as text, refresh_token) => TokenMethod(NormalizeUrlScheme(resourceUrl), refresh_token, "refresh_token");

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
    parts  = Uri.Parts(baseUrl),
    scheme = parts[Scheme],
    host   = parts[Host],
    port   = if Record.HasFields(parts, "Port") and parts[Port] <> null
             then ":" & Text.From(parts[Port])
             else "",

    // Credential scope root — no trailing slash
    credRoot = scheme & "://" & host & port,

    // Full path including relative path
    fullRelative = Text.TrimStart(relativePath, "/"),

    headers = GetAuthHeaders(),

    // Diagnostics
    _root = LogValue("Frappe root", credRoot),
    _path = LogValue("Frappe relativePath", fullRelative),
    _qry  = LogValue("Frappe query", query),

    optionsBase =
        if query <> null then
            [
                Headers = headers,
                RelativePath = fullRelative,
                Query = query
            ]
        else
            [
                Headers = headers,
                RelativePath = fullRelative
            ],

    options =
        Record.Combine({
            optionsBase,
            [
                ManualCredentials = true,
                ManualStatusHandling = {400,401,403,404,409,417,422,429,500,501,502,503}
            ]
        }),

    // Log Web.Contents failures
    response =
        LogFailure(
            "Web.Contents failed",
            () => Web.Contents(credRoot, options)
        ),

    meta_res = Value.Metadata(response),

    status =
        if Record.HasFields(meta_res, "Response.Status")
        then meta_res[#"Response.Status"]
        else 200,

    // Log Json.Document failures
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
                "FrappeReports",
                "HTTP " & Text.From(status) & " - " & GetFrappeErrorMessage(body),
                body
            ),

    // 2) Soft errors (HTTP 200 but Frappe exception payload)
    _soft =
        if bodyJson <> null and IsFrappeErrorPayload(bodyJson) then
            error Error.Record(
                "FrappeReports",
                "Frappe Error - " & GetFrappeErrorMessage(bodyJson),
                bodyJson
            )
        else
            null
in
    if bodyJson <> null then bodyJson else error Error.Record("FrappeReports", "Non-JSON response.", bodyText);

// Your old Feed can stay (returns raw JSON from base URL)
FrappeReportsImpl = (url as text) as any =>
let
    root = NormalizeUrlScheme(url),
    raw  = Web.Contents(root, [Headers = GetAuthHeaders(), ManualCredentials = true]),
    json = Json.Document(raw)
in
    json;

// ----------------------------
// Step 1: Fetch list of enabled reports
// ----------------------------
GetReportsList = (baseUrl as text) as table =>
let
    json = FrappeGetJson(
        baseUrl,
        "/api/method/pbi_integration.api.reports.get_report_sources",
        [
            fields   = "[""name"",""report"",""user""]",
            order_by = "name"
        ]
    ),

    // message is a list directly not json[message][data]
    rows =
        if IsFrappeErrorPayload(json) then
            error Error.Record(
                "FrappeReports",
                "Frappe Error - " & GetFrappeErrorMessage(json),
                json
            )
        else if not Record.HasFields(json, "message") then
            error Error.Record(
                "FrappeReports",
                "Report sources did not return [message]. Fields present: " & Text.Combine(Record.FieldNames(json), ", "),
                json
            )
        else
            json[message],

    t0 = Table.FromRecords(rows),

    t1 = Table.TransformColumns(
        t0,
        {
            {"name",   each Text.From(_), type text},
            {"report", each try Text.From(_) otherwise null, type nullable text},
            {"user",   each try Text.From(_) otherwise null, type nullable text}
        }
    )
in
    t1;

// ----------------------------
// Filters table helper
// ----------------------------
GetFiltersForReport = (filtersTable as table, reportName as text) as text =>
let
    rows = Table.SelectRows(
        filtersTable,
        each Text.Lower(Text.Trim([report_name])) = Text.Lower(Text.Trim(reportName))
    ),

    records = Table.ToRecords(rows),

    asRecord =
        Record.FromList(
            List.Transform(records, each Text.From([value])),
            List.Transform(records, each Text.From([field_name]))
        ),

    json =
        if Record.FieldCount(asRecord) = 0 then "{}"
        else Text.FromBinary(Json.FromValue(asRecord))
in
    json;

// Same type mapping as DocTypes connector
ReportFieldTypeToMType = (ft as nullable text) as type =>
let
    x = if ft = null then "" else Text.Lower(Text.Trim(ft)),
    t =
        if List.Contains({"int", "integer"}, x) then Int64.Type
        else if List.Contains({"float", "currency", "percent"}, x) then type number
        else if List.Contains({"check", "boolean"}, x) then type logical
        else if x = "date" then type date
        else if x = "datetime" then type datetime
        else if x = "time" then type time
        else type text
in
    t;

// Converts the `columns` array from the report API response
ParseReportColumns = (columns as list) as table =>
let
    rows =
        List.RemoveNulls(
            List.Transform(
                columns,
                (col) =>
                let
                    isRecord = col is record,
                    isText   = col is text,

                    fieldname =
                        if isRecord then
                            try Text.Trim(Text.From(col[fieldname])) otherwise null
                        else if isText then
                            let parts = Text.Split(col, ":")
                            in if List.Count(parts) >= 1 then Text.Trim(parts{0}) else null
                        else
                            null,

                    fieldtype =
                        if isRecord then
                            try Text.Trim(Text.From(col[fieldtype])) otherwise null
                        else
                            null,

                    mtype = ReportFieldTypeToMType(fieldtype)
                in
                    if fieldname = null or fieldname = "" then null
                    else { fieldname, mtype }
            )
        ),

    schema = #table({"Name", "Type"}, rows)
in
    schema;

// ----------------------------
// Step 3: Fetch report data from Frappe

GetReportData = (baseUrl as text, reportSourceName as text, filtersJson as text) as table =>
let
    json = FrappeGetJson(
        baseUrl,
        "/api/method/pbi_integration.api.reports.get_report_source_content",
        [
            report_source = reportSourceName,
            filters       = filtersJson,
            for_preview   = "0"
        ]
    ),

    message =
        if IsFrappeErrorPayload(json) then
            error Error.Record(
                "FrappeReports",
                "Report source '" & reportSourceName & "' failed: " & GetFrappeErrorMessage(json),
                json
            )
        else if not Record.HasFields(json, "message") then
            error Error.Record(
                "FrappeReports",
                "Report source '" & reportSourceName & "' returned no [message]. Fields: " & Text.Combine(Record.FieldNames(json), ", "),
                json
            )
        else
            json[message],

    rawColumns =
        if Record.HasFields(message, "columns") then message[columns]
        else error Error.Record("FrappeReports", "No [columns] in response.", message),

    rawRows =
        if Record.HasFields(message, "result") then message[result]
        else error Error.Record("FrappeReports", "No [result] in response.", message),

    schema    = ParseReportColumns(rawColumns),
    cleanRows = List.Select(rawRows, (row) => row is record and Record.FieldCount(row) > 1),

    t0 =
        if List.IsEmpty(cleanRows) then
            #table({}, {})
        else
            let
                allFields  = List.Union(List.Transform(cleanRows, Record.FieldNames)),
                normalized = List.Transform(
                    cleanRows,
                    (row) => Record.FromList(
                        List.Transform(allFields, (f) => try Record.Field(row, f) otherwise null),
                        allFields
                    )
                )
            in
                Table.FromRecords(normalized),

    t1 = SchemaTransformTable(t0, schema, EnforceSchema.IgnoreExtraColumns)
in
    t1;

// ----------------------------
// Schema helpers (same as DocTypes connector)
// ----------------------------
EnforceSchema.Strict              = 1;
EnforceSchema.IgnoreExtraColumns  = 2;
EnforceSchema.IgnoreMissingColumns = 3;

CleanSchema = (schema as table) as table =>
let
    s0 = Table.SelectColumns(schema, {"Name","Type"}, MissingField.Error),
    s1 = Table.TransformColumns(s0, {{"Name", each Text.From(_), type text}}),
    s2 = Table.SelectRows(s1, each Value.Is([Type], type type)),
    s3 = Table.Distinct(s2, {"Name"})
in
    s3;

SchemaTransformTable = (table as table, schema as table, optional enforceSchema as number) as table =>
let
    _enforceSchema = if enforceSchema <> null then enforceSchema else EnforceSchema.Strict,
    schemaClean    = CleanSchema(schema),
    existing       = Table.ColumnNames(table),
    schema2        = Table.SelectRows(schemaClean, each List.Contains(existing, [Name])),
    transforms     =
        List.Transform(
            Table.ToRecords(schema2),
            each { _[Name], if Value.Is(_[Type], type type) then _[Type] else type any }
        ),
    typed =
        if List.IsEmpty(transforms) then table
        else Table.TransformColumnTypes(table, transforms),
    schemaNames = schemaClean[Name],
    addNames    = List.RemoveItems(schemaNames, Table.ColumnNames(typed)),
    added       =
        List.Accumulate(
            addNames,
            typed,
            (st, col) => Table.AddColumn(st, col, each null)
        ),
    fullList =
        if _enforceSchema = EnforceSchema.Strict then schemaNames
        else if _enforceSchema = EnforceSchema.IgnoreMissingColumns then Table.ColumnNames(added)
        else schemaNames & List.RemoveItems(Table.ColumnNames(added), schemaNames),
    reordered = Table.SelectColumns(added, fullList, MissingField.Ignore)
in
    reordered;

// ----------------------------
// Step 4: Report Table with Table.View
// ----------------------------
GetReportTable = (baseUrl as text, reportSourceName as text, filtersInput as any) as table =>
let
    dataTable = GetReportData(baseUrl, reportSourceName, filtersInput),
    schema    = Value.Type(dataTable),

    View = (state as record) as table =>
        Table.View(
            null,
            [
                GetType = () as type => schema,

                GetRows = () as table =>
                let
                    localCond = Record.FieldOrDefault(state, "LocalRowFilter", null),
                    out0 =
                        if localCond <> null then
                            Table.SelectRows(dataTable, localCond)
                        else
                            dataTable,
                    cols = Record.FieldOrDefault(state, "Columns", null),
                    out1 =
                        if cols <> null then
                            Table.SelectColumns(out0, cols, MissingField.Ignore)
                        else
                            out0
                in
                    out1,

                GetRowCount = () as number => Table.RowCount(dataTable),
                OnTake = (count as number) as table => @View(state & [Take = count]),
                OnSkip = (count as number) as table => @View(state & [Skip = count]),
                OnSelectColumns = (cols as list) as table => @View(state & [Columns = cols]),
                OnSelectRows = (condition as function) as table => @View(state & [LocalRowFilter = condition])
            ]
        ),

    out = View([])
in
    out;

// ----------------------------
// Step 5: Navigation Table
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
            NavigationTable.NameColumn    = nameColumn,
            NavigationTable.DataColumn    = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn,
            NavigationTable.ItemNameColumn = itemNameColumn,
            NavigationTable.IsLeafColumn  = isLeafColumn,
            Preview.DelayColumn           = dataColumn
        ],
    navTable = Value.ReplaceType(table, navType)
in
    navTable;

FrappeReportsNavTable = (url as text, filtersInput as any) as table =>
let
    baseUrl   = Text.From(url),
    reports   = GetReportsList(baseUrl),
    namesOnly = Table.Distinct(Table.SelectColumns(reports, {"name"})),

    withData =
        Table.AddColumn(
            namesOnly,
            "Data",
            each GetReportTable(baseUrl, [name], filtersInput),
            type table
        ),

    withKind   = Table.AddColumn(withData,   "ItemKind", each "Table", type text),
    withItemNm = Table.AddColumn(withKind,   "ItemName", each "Table", type text),
    withLeaf   = Table.AddColumn(withItemNm, "IsLeaf",   each true,    type logical),

    nav = Table.ToNavigationTable(
        withLeaf,
        {"name"},
        "name",
        "Data",
        "ItemKind",
        "ItemName",
        "IsLeaf"
    )
in
    nav;


FrappeReportsPath = (url as text, optional filtersJson as nullable text) as text =>
let
    // Normalize and clean URL structure
    normalized = NormalizeUrlScheme(url),
    parts = Uri.Parts(normalized),

    // Reconstruct cleanly using text concatenation
    // (Power Query M doesn't have Uri.FromParts; must build manually)
    scheme = "https",
    host = parts[Host],
    port = if Record.HasFields(parts, "Port") and parts[Port] <> null and parts[Port] <> 443
           then ":" & Text.From(parts[Port])
           else "",
    path = if parts[Path] <> null then parts[Path] else "",

    // Reconstruct base URL (scheme + host + port)
    rebuilt = scheme & "://" & host & port
in
    rebuilt;

FrappeReports = [
    Authentication = [
        OAuth = [
            StartLogin  = StartLogin,
            FinishLogin = FinishLogin,
            Refresh     = Refresh,
            Label       = "Frappe Account"
        ],
        Key = [
            Label = "API Key"
        ]
    ],
    Label = "Frappe Reports",
    DataSource.Path = FrappeReportsPath,
    TestConnection = (dataSourcePath) => { "FrappeReports.Contents", dataSourcePath },
    CredentialScope = [
        Default = [
            AuthorizationUri = "",
            Resource = "https://",
            Scope = {}
        ]
    ]
];


FrappeReports.Icons = [
    Icon16 = { Extension.Contents("FrappeReports16.png"), Extension.Contents("FrappeReports20.png"), Extension.Contents("FrappeReports24.png"), Extension.Contents("FrappeReports32.png") },
    Icon32 = { Extension.Contents("FrappeReports40.png"), Extension.Contents("FrappeReports48.png"), Extension.Contents("FrappeReports64.png"), Extension.Contents("FrappeReports80.png") }
];

FrappeReports.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { "Frappe Reports", "Frappe Reports" },
    SourceImage = FrappeReports.Icons,
    SourceTypeImage = FrappeReports.Icons
];