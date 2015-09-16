/* X Resource Manager Intrinsics */
module iv.x11.resource is aliced;

import iv.x11.xlib;

extern (C) @trusted nothrow @nogc:

/* Memory Management */
char* Xpermalloc (uint size);

/* Quark Management */
//typedef XrmQuark = int;
alias XrmQuark = int;
//typedef XrmQuarkList = int*;
alias XrmQuarkList = int*;
enum XrmQuark NULLQUARK = 0;

alias XrmString = char*;
immutable XrmString NULLSTRING = null;

/* find quark for string, create new quark if none already exists */
XrmQuark XrmStringToQuark (const(char)* str);

XrmQuark XrmPermStringToQuark (const(char)* str);

/* find string for quark */
XrmString XrmQuarkToString (XrmQuark quark);

XrmQuark XrmUniqueQuark ();

//???
bool XrmStringsEqual (XrmString a1, XrmString a2) { return (*a1 == *a2); }


/* Conversion of Strings to Lists */
//typedef XrmBinding = int;
alias XrmBinding = int;
enum { XrmBindTightly, XrmBindLoosely }
//typedef XrmBindingList = XrmBinding*;
alias XrmBindingList = XrmBinding*;

void XrmStringToQuarkList (const(char)* str, XrmQuarkList quarks_return);

void XrmStringToBindingQuarkList (const char* str, XrmBindingList bindings_return, XrmQuarkList quarks_return);

/* Name and Class lists. */
//typedef XrmName = XrmQuark;
alias XrmName = XrmQuark;
//typedef XrmNameList = XrmQuarkList;
alias XrmNameList = XrmQuarkList;

XrmString XrmNameToString (XrmName name) { return XrmQuarkToString(cast(XrmQuark)name); }
XrmName XrmStringToName (XrmString str) { return cast(XrmName) XrmStringToQuark(str); }
void XrmStringToNameList (XrmString str, XrmNameList name) { XrmStringToQuarkList(str, name); }

//typedef XrmClass = XrmQuark;
alias XrmClass = XrmQuark;
//typedef XrmClassList = XrmQuarkList;
alias XrmClassList = XrmQuarkList;

XrmString XrmClassToString (XrmClass c_class) { return XrmQuarkToString(cast(XrmQuark)c_class); }
XrmClass XrmStringToClass (XrmString c_class) { return cast(XrmClass)XrmStringToQuark(c_class); }
void XrmStringToClassList (XrmString str, XrmClassList c_class) { XrmStringToQuarkList(str, c_class); }


/* Resource Representation Types and Values */
//typedef XrmRepresentation = XrmQuark;
alias XrmRepresentation = XrmQuark;

XrmRepresentation XrmStringToRepresentation (XrmString str) { return cast(XrmRepresentation)XrmStringToQuark(str); }
XrmString XrmRepresentationToString( XrmRepresentation type) { return XrmQuarkToString(type); }

struct XrmValue {
  uint size;
  XPointer addr;
}
alias XrmValuePtr = XrmValue*;


/* Resource Manager Functions */
struct _XrmHashBucketRec {}
alias XrmHashBucket = _XrmHashBucketRec*;
alias XrmHashTable = XrmHashBucket*;
alias XrmSearchList = XrmHashTable[];
alias XrmDatabase = _XrmHashBucketRec*;

void XrmDestroyDatabase (XrmDatabase database);
void XrmQPutResource (XrmDatabase* database, XrmBindingList bindings, XrmQuarkList quarks, XrmRepresentation type, XrmValue* value);
void XrmPutResource (XrmDatabase* database, const(char)* specifier, const(char)* type, XrmValue* value);
void XrmQPutStringResource (XrmDatabase* database, XrmBindingList bindings, XrmQuarkList quarks, const(char)* value);
void XrmPutStringResource (XrmDatabase* database, const(char)* specifier, const(char)* value);
void XrmPutLineResource (XrmDatabase* database, const(char)* line);
Bool XrmQGetResource (XrmDatabase database, XrmNameList quark_name, XrmClassList quark_class, XrmRepresentation* quark_type_return, XrmValue* value_return);
Bool XrmGetResource (XrmDatabase database, const(char)* str_name, const(char)* str_class, char** str_type_return, XrmValue* value_return);
Bool XrmQGetSearchList (XrmDatabase database, XrmNameList names, XrmClassList classes, XrmSearchList list_return, int list_length);
Bool XrmQGetSearchResource (XrmSearchList list, XrmName name, XrmClass rsclass, XrmRepresentation* type_return, XrmValue* value_return);

/* Resource Database Management */
void XrmSetDatabase (Display* display, XrmDatabase database);
XrmDatabase XrmGetDatabase (Display* display);
XrmDatabase XrmGetFileDatabase (const(char)* filename);
Status XrmCombineFileDatabase (const(char)* filename, XrmDatabase* target, Bool dooverride);
XrmDatabase XrmGetStringDatabase (const(char)* data /* null terminated string */);
void XrmPutFileDatabase (XrmDatabase database, const(char)* filename);
void XrmMergeDatabases (XrmDatabase source_db, XrmDatabase* target_db);
void XrmCombineDatabase (XrmDatabase source_db, XrmDatabase* target_db, Bool dooverride);

enum uint XrmEnumAllLevels = 0;
enum uint XrmEnumOneLevel  = 1;

Bool XrmEnumerateDatabase (
    XrmDatabase db,
    XrmNameList name_prefix,
    XrmClassList class_prefix,
    int mode,
    Bool function (
         XrmDatabase* db,
         XrmBindingList bindings,
         XrmQuarkList quarks,
         XrmRepresentation* type,
         XrmValue* value,
         XPointer closure
    ) proc,
    XPointer closure
);

char* XrmLocaleOfDatabase (XrmDatabase database);


/* Command line option mapping to resource entries */

alias XrmOptionKind = int;
enum {
  XrmoptionNoArg,     /* Value is specified in OptionDescRec.value */
  XrmoptionIsArg,     /* Value is the option string itself */
  XrmoptionStickyArg, /* Value is characters immediately following option */
  XrmoptionSepArg,    /* Value is next argument in argv */
  XrmoptionResArg,    /* Resource and value in next argument in argv */
  XrmoptionSkipArg,   /* Ignore this option and the next argument in argv */
  XrmoptionSkipLine,  /* Ignore this option and the rest of argv */
  XrmoptionSkipNArgs, /* Ignore this option and the next OptionDescRes.value arguments in argv */
}

struct XrmOptionDescRec {
  char* option;          /* Option abbreviation in argv */
  char* specifier;       /* Resource specifier */
  XrmOptionKind argKind; /* Which style of option it is */
  XPointer value;        /* Value to provide if XrmoptionNoArg */
}
alias XrmOptionDescList = XrmOptionDescRec*;

void XrmParseCommand (XrmDatabase* database, XrmOptionDescList table, int table_count,
  const(char)* name, int* argc_in_out, char** argv_in_out);
