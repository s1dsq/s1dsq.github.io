# Pydantic: a simple case study

2024-04-05

[Pydantic](https://docs.pydantic.dev/latest/) is a data validation library for
python. In this post I want to contrast it with using plain python by writing a
short program

We will parse the output of the [hottest](https://lobste.rs/hottest.json) posts
from [lobste.rs](https://lobste.rs/) which is a link aggregator like hackernews
focused on computing

The code for this post is available
[here](https://github.com/s1dsq/pydantic-case-study)

## Regular python

The hottest posts is a json array and each entry is of the following format:
```json
{
    "short_id": "pkgjno",
    "short_id_url": "https://lobste.rs/s/pkgjno",
    "created_at": "2024-03-30T16:16:16.000-05:00",
    "title": "Type Inference Was a Mistake",
    "url": "https://borretti.me/article/type-inference-was-a-mistake",
    "score": 36,
    "flags": 0,
    "comment_count": 32,
    "description": "",
    "description_plain": "",
    "comments_url": "https://lobste.rs/s/pkgjno/type_inference_was_mistake",
    "submitter_user": "puffnfresh",
    "user_is_author": false,
    "tags": ["plt"]
},
```

We want to read each entry and parse the fields of interest which is represented
as:
```python
@dataclass
class LobstersPost:
    created_at: datetime
    title: str
    url: str
    score: int
    comments_url: str
    tags: list[str]
```

Here is core parsing function:
```python
def parse_post(post: dict) -> typing.Union[LobstersPost, None]:
    created_at: datetime = datetime.now()
    title: str = ""
    url: str = ""
    score: int = 0
    comments_url: str = ""
    tags: list[str] = []

    try:
        errors = []
        for k, v in post.items():
            if k == "created_at":
                try:
                    created_at = datetime.strptime(v, "%Y-%m-%dT%H:%M:%S.%f%z")
                except ValueError as e:
                    errors.append("failed to parse datetime" + str(e))
            elif k == "title":
                if isinstance(v, str):
                    title = v
                else:
                    errors.append(f"cannot convert {type(v)} to str")
            elif k == "url":
                if isinstance(v, str):
                    url = v
                else:
                    errors.append(f"cannot convert {type(v)} to str")
            elif k == "score":
                if isinstance(v, int):
                    score = v
                else:
                    errors.append(f"cannot convert {type(v)} to int")
            elif k == "comments_url":
                if isinstance(v, str):
                    comments_url = v
                else:
                    errors.append(f"cannot convert {type(v)} to str")
            elif k == "tags":
                if isinstance(v, list):
                    tags = []
                    for tag in v:
                        if isinstance(tag, str):
                            tags.append(tag)
                        else:
                            errors.append(f"cannot convert {type(tag)} to int")
                else:
                    errors.append(f"cannot convert {type(v)} to list[str]")

        if len(errors) != 0:
            raise ValidationError(errors)
        return LobstersPost(
            created_at=created_at,
            title=title,
            url=url,
            score=score,
            comments_url=comments_url,
            tags=tags,
        )
    except ValidationError as e:
        print(e.errors())
        return None
```

Here `ValidationError` is a custom Exception I have defined. We are validating
each field if present and checking if the values are of the proper types, making
heavy use of the builtin function `isinstance`. Some observations:
- The parsing function is rather verbose. Imagine having many schemas all over
  the codebase and writing these kinds of functions for all of them. This
  quickly gets out of hand
- If the schema changes, we have to change the parsing function as well
- Nested types are a chore to validate
- The datetime validation does not handle different formats. That adds further
  complexities

## Pydantic

Let's write the same `parse_post` function using pydantic. We define the schema
first:

```python
class LobstersPost(BaseModel):
    created_at: datetime
    title: str
    url: str
    score: int
    comments_url: str
    tags: list[str]
```
`BaseModel` is a part of pydantic. It is like a dataclass except it boasts more
features as advertised in the docs. Let's check the parsing function which is
laughably small:

```python
def parse_post(post: dict) -> typing.Union[LobstersPost, None]:
    try:
        p = LobstersPost(**post)
        return p
    except ValidationError as e:
        print(e.errors())
        return None
```

All our concerns with using just python are taken care of now. But here are some
cases where you may not need the powers of pydantic:
- When the data does not leave the system boundary. Simple dataclasses will do
  here as the programmer guarantees the types
- Pydantic has many features baked in and a steeper learning curve. For simpler
  use cases you may not need them

## Conclusion

I read [Parse, don't
validate](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/) a
while back and was immediately sold on the idea but had no idea how to apply it
in languages like python.

The core idea of the article is that we must transform unstructured data into
structured data only once and encode that information in the type system so that
it never needs to be checked again. In practice this means:
- Choose data structures that make illegal state unrepresentable
- Push the burden of _validation_ at the system boundary

Pydantic aids in our quest to validate early
