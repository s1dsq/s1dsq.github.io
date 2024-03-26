# Writing a primitive version of git

2024-03-24

Most of us use the git version control everyday. Git has a bad UI as many people
have complained on the internet before. But understanding the internals allows
us to better use this piece of software on a day to day basis. Also, it helps
demystify the "magic" a little bit.

In this post, we will write a very basic version of git in golang that we can
push to github as a remote using the git command line. Along the way we will
understand how git stores objects on disk which is the secret sauce to the dish
that is git.

## What is git?
At its core, git is a content-addressable filesystem. This means it is a key
value store on disk. You can store any content on disk and address it using a
key that git gives you. If we tap into this store and write data to it manually
using our program, we can make git think that we ran a bunch of porcelain
commands (git init, git checkout etc. Basically any user-friendly
command)

Git store all of this key-value information and more in a `.git` directory in
the root of your repository. This is automatically created when we run `git
init` to initialize a new repository.

## What?
Here is what we want to do:

- Initialize a new git repository
- Create a new file with some content
- Add one commit to the master branch where we add the file

This will give us enough to push the repository to github as a remote

## How?

Our script does the following:

- Create a `HEAD` file at `.git/HEAD`
- Create blob -> tree -> commit objects in `.git/objects`
- Create a ref file at `.git/refs/heads/master` to point to the commit we
  created

Now we go into detail for each of the steps outlined above.

### The HEAD

The HEAD is a pointer to a reference which is a currently checked out in our
repo. We can change where HEAD points to using commands like `git checkout` or
`git switch`

We point HEAD to the `master` branch. Here is the code to do that:

```go
err := os.WriteFile(filepath.Join(".git", "HEAD"), []byte("ref: refs/heads/master\n"), 0644)
if err != nil {
    log.Fatal(err)
}
```
Here HEAD points to the reference master. `.git/refs/heads/master` will tell us
where master actually points to

### Creating the right objects

An object is something that is stored on the disk and can be referred to using a
key. Git stores files, commits, tags and many other things as objects. The three
types of objects relevant to our discussion are:

- **blob**: git represents file contents as blobs. This is the foundation object
  in many ways
- **tree**: this represents a directory on the filesystem. Trees can contain
  other trees and blobs. The representation is similar to a UNIX filesystem
- **commit**: this object stores a snapshot of the git repo and contains
  information like the tree which it points to, the author of the commit, a
  message describing why the commit was made etc.

Objects are stored in the `.git/objects` directory. You can go to any git repo
and see any object using the following plumbing command:
```
git cat-file -p 7108f7ecb345ee9d0084193f147cdad4d2998293
```

The long string at the end is the object hash which is the key mentioned
earlier. This is the SHA-1 hash of the contents of the objects and it is stored
on disk like so:
```
.git/objects/71/08f7ecb345ee9d0084193f147cdad4d2998293
```

But running the above cat-file command shows us a bunch of gibberish. This is
because git uses [zlib](https://en.wikipedia.org/wiki/Zlib) to compress the
contents before writing the objects to disk. So, the order is:
- Use some logic to get the contents of the object (more on this later)
- Compress the contents using zlib
- Write the compressed contents to a file path constructed using the hash of the
  uncompressed contents

Each object comprises of two parts, the header and the content. The header is
concatenated with the content to get the final object that is stored on disk
after compression. The header for a tree object looks like:

```go
header = "tree " + strconv.Itoa(len([]byte(content))) + "\000"
```

The header format looks like `<objectType> len(content)\0` (\0 is the null
byte). Here *content* is the stuff that follows \0. Replace the word "tree" with
"blob" and "commit" to get the header format for blobs and commits respectively

```go
func getObject(content, objectType string) (string, bytes.Buffer) {
	var header string
	var store string
	switch objectType {
	case "blob":
		header = "blob " + strconv.Itoa(len([]byte(content))) + "\000"
	case "tree":
		header = "tree " + strconv.Itoa(len([]byte(content))) + "\000"
	case "commit":
		header = "commit " + strconv.Itoa(len([]byte(content))) + "\000"
	default:
		fmt.Println("Unhandled object type", objectType)
	}
	store = header + content

	// the content of the object stored on disk
	var zlibContent bytes.Buffer
	w := zlib.NewWriter(&zlibContent)
	w.Write([]byte(store))
	w.Close()

	// used for creating object filename
	hash := sha1.Sum([]byte(store))
	return hex.EncodeToString(hash[:]), zlibContent
}
```

The getObject function takes in some content and returns the zlib compressed
data and SHA-1 hash. We call this function for each of the three types of
objects. Let's look at the content for each type of object.

```go
content := "what is up, doc?\n"
blobHash, zlibContent := getObject(content, "blob")
err = writeObject(filepath.Join(objectsDir, blobHash[0:2]), blobHash[2:], zlibContent.Bytes())
if err != nil {
	log.Fatal("failed to write blob object", err)
}
```

The blob stores the contents "what is up, doc?\n". We write the contents to disk
using the writeObject function.

```go
func writeObject(dirName, fileName string, content []byte) error
```

We construct the directory name by using the first two characters of the SHA1
hash of the object along with the base objects directory
```go
var objectsDir = filepath.Join(".git", "objects")
```
Content of the *tree* object:

```go
// concat hash of previous blob in binary format: https://stackoverflow.com/a/33039114
decoded, _ := hex.DecodeString(blobHash)
content = "100644 hello.txt\000" + string(decoded[:])
treeHash, zlibContent := getObject(content, "tree")
err = writeObject(filepath.Join(objectsDir, treeHash[0:2]), treeHash[2:], zlibContent.Bytes())
if err != nil {
    log.Fatal("failed to write tree object", err)
}
```
Here we add a blob called hello.txt with permission 100644. The permissions are
similar to UNIX ones, except they are very restrictive (100644 for blobs, 040000
for trees etc.)

The content format for trees is a little different from those of blobs and
commits:
```
tree [content size]\0[Entries having references to other trees and blobs]
[mode] [file/folder name]\0[SHA-1 of referencing blob or tree]
```

Note that the SHA-1 of referencing blobs/trees should be in binary format. Refer
[here](https://stackoverflow.com/a/33039114) for more details

If we have more than one entry for referencing blob/tree, it should be sorted
lexicographically based on path

More information can be found on this
[stackoverflow](https://stackoverflow.com/questions/14790681/what-is-the-internal-format-of-a-git-tree-object)
post

The commit contents are similar to blobs:
```go
content = "tree " + treeHash + "\nauthor Siddharth Singh <me@s1dsq.com> 1708260537 +0530\ncommitter Siddharth Singh <me@s1dsq.com> 1708260537 +0530\n\nAdd hello.txt\n"
commitHash, zlibContent := getObject(content, "commit")
err = writeObject(filepath.Join(objectsDir, commitHash[0:2]), commitHash[2:], zlibContent.Bytes())
if err != nil {
    log.Fatal("failed to write commit object", err)
}
```

Commit hashes are non-deterministic as they contain timestamp which can change.
I have used fixed timestamp to make the hash deterministic and reproducible

### Point master to the commit

A commit is freestanding entity in the object universe. We point hashes to human
readable references to help us keep track of a chain of commits. Here is the
code to do it:

```go
// point "master" ref to the commit hash we just created
createDir(".git/refs/heads")
err = os.WriteFile(filepath.Join(".git", "refs", "heads", "master"), []byte(commitHash), 0644)
if err != nil {
    log.Fatal("failed to write refs/heads", err)
}
```

Running `git log` shows us the commit we just created

## Conclusion

Add a git remote of your choice like and push to it:
```
git remote add origin git@github.com:s1dsq/basic-git-repo.git
git push -u origin master
```

Check the repo on github to see that we have a file called hello.txt on the
master branch with one commit on it

The go script used in the post is available [here](https://github.com/s1dsq/primitive-git)
