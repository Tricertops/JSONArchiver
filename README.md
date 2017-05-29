NSCoder for JSON format
===============

This is project in development. Its aim is to create drop-in replacement for `NSKeyedArchiver` and `NSKeyedUnarchiver` that produce archives in JSON format. These archives will preserve classes, cyclic references, conditional references and will use native JSON types as much as possible to produce _pretty_ and compact results.

---

Actual result after encoding several keyed root objects:

```objc
var archiver = [JSONArchiver new];
archiver.shouldPrettyPrint = YES;

[archiver encodeObject:@"Lorem ipsum" forKey:@"title"];
[archiver encodeObject:nil forKey:@"subtitle"];
[archiver encodeInteger:2017 forKey:@"year"];
[archiver encodeBool:YES forKey:@"isWorking"];
[archiver encodeObject:URL forKey:@"website"];

NSLog(archiver.JSONString); // Result is below.
```

```json
{
  "title" : "Lorem ipsum",
  "subtitle" : null,
  "year" : 2017,
  "isWorking" : true,
  "website" : {
    "#url" : "https:\/\/developer.apple.com"
  }
}
```

---

More complex example with multiple objects and cyclic references:

```objc
// Standard object implementing NSCoding.
@implementation Person

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeInteger:self.age forKey:@"age"];
    [encoder encodeObject:self.partner forKey:@"partner"];
    [encoder encodeObject:self.children forKey:@"children"];
}

@end
```

```objc
// Archive single root object.
[archiver encodeRootObject:@[person1, person2]];
```

```json
[
  {
    "#class" : "NSArray",
    "#objects" : [
      { "#ref" : 1 },
      { "#ref" : 2 }
    ]
  },
  {
    "#class" : "Person",
    "age" : 45,
    "name" : "Mom",
    "partner" : { "#ref" : 2 },
    "children" : { "#ref" : 3 }
  },
  {
    "#class" : "Person",
    "age" : 48,
    "name" : "Dad",
    "partner" : { "#ref" : 1 },
    "children" : { "#ref" : 3 }
  },
  {
    "#class" : "NSArray",
    "#objects" : [
      { "#ref" : 4 },
      { "#ref" : 5 }
    ]
  },
  {
    "#class" : "Person",
    "age" : 8,
    "name" : "Alex",
    "partner" : null,
    "children" : null
  },
  {
    "#class" : "Person",
    "age" : 4,
    "name" : "Chris",
    "partner" : null,
    "children" : null
  }
]
```

---

Unarchiver is not yet implemented 😜
