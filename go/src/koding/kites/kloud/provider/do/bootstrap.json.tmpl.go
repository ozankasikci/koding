// Code generated by go-bindata.
// sources:
// bootstrap.json.tmpl
// DO NOT EDIT!

package do

import (
	"bytes"
	"compress/gzip"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func bindataRead(data []byte, name string) ([]byte, error) {
	gz, err := gzip.NewReader(bytes.NewBuffer(data))
	if err != nil {
		return nil, fmt.Errorf("Read %q: %v", name, err)
	}

	var buf bytes.Buffer
	_, err = io.Copy(&buf, gz)
	clErr := gz.Close()

	if err != nil {
		return nil, fmt.Errorf("Read %q: %v", name, err)
	}
	if clErr != nil {
		return nil, err
	}

	return buf.Bytes(), nil
}

type asset struct {
	bytes []byte
	info  os.FileInfo
}

type bindataFileInfo struct {
	name    string
	size    int64
	mode    os.FileMode
	modTime time.Time
}

func (fi bindataFileInfo) Name() string {
	return fi.name
}
func (fi bindataFileInfo) Size() int64 {
	return fi.size
}
func (fi bindataFileInfo) Mode() os.FileMode {
	return fi.mode
}
func (fi bindataFileInfo) ModTime() time.Time {
	return fi.modTime
}
func (fi bindataFileInfo) IsDir() bool {
	return false
}
func (fi bindataFileInfo) Sys() interface{} {
	return nil
}

var _bootstrapJsonTmpl = []byte("\x1f\x8b\x08\x00\x00\x09\x6e\x88\x00\xff\xa4\x91\x4d\x6a\xec\x30\x10\x84\xf7\x3e\x45\x23\xde\xd2\xf8\x00\xef\x0a\x03\x21\x37\x30\x3d\x52\x8f\xd3\x58\x91\x8c\x7e\x0c\xc6\xe8\xee\x41\x1e\x79\x2c\x27\x93\x6c\x66\xa9\x56\xd5\x57\x4d\xf5\xda\x00\x88\xc9\xd9\x99\x15\x39\xf1\x1f\xf2\x1b\x40\x28\x1e\x38\xa0\xb6\x92\xd0\x3c\xa6\x00\x22\xd8\x91\xf2\x40\xfc\x5b\x67\x74\x5d\x2d\xeb\x51\x4a\xf2\xbe\xdf\x24\x49\x6c\x8e\xd4\x00\xa4\x36\x47\xd8\x18\xa6\x18\x8e\x80\x91\x96\xde\xe0\x27\xd5\xf0\x19\x75\xa4\x3b\xfc\x04\xf6\xfe\xa3\x1f\x69\xe9\x46\xab\xd8\x0c\x8f\x67\xb6\xef\x39\xed\x41\xbd\xb1\x19\xc8\x4d\x8e\x4d\x78\x01\x5e\x51\x9e\x64\xb0\x7a\x01\xcd\xea\x47\x3b\x8e\xbc\x8d\x4e\xd2\xf3\x03\xec\xce\x3a\xf3\xcc\xac\x7e\x00\x44\xe9\xb5\xdc\x68\x6f\x3a\x89\xf6\x90\x4c\xf1\xaa\x59\x16\x6b\x11\x1e\xb3\xb2\xdf\x7d\xc3\x7a\xcf\x19\x1d\xe3\x55\xd3\xdf\x77\x54\x74\xc3\xa8\x73\xfb\x62\x5d\xbb\x0b\x2d\x6f\x39\xfe\x5b\x8d\xa7\x0d\x7e\xb1\xbe\x6f\x9a\x0b\x2d\xa9\x6e\xac\x49\xcd\x57\x00\x00\x00\xff\xff\x67\x83\x2f\xe2\xb6\x02\x00\x00")

func bootstrapJsonTmplBytes() ([]byte, error) {
	return bindataRead(
		_bootstrapJsonTmpl,
		"bootstrap.json.tmpl",
	)
}

func bootstrapJsonTmpl() (*asset, error) {
	bytes, err := bootstrapJsonTmplBytes()
	if err != nil {
		return nil, err
	}

	info := bindataFileInfo{name: "bootstrap.json.tmpl", size: 694, mode: os.FileMode(420), modTime: time.Unix(1476478846, 0)}
	a := &asset{bytes: bytes, info: info}
	return a, nil
}

// Asset loads and returns the asset for the given name.
// It returns an error if the asset could not be found or
// could not be loaded.
func Asset(name string) ([]byte, error) {
	cannonicalName := strings.Replace(name, "\\", "/", -1)
	if f, ok := _bindata[cannonicalName]; ok {
		a, err := f()
		if err != nil {
			return nil, fmt.Errorf("Asset %s can't read by error: %v", name, err)
		}
		return a.bytes, nil
	}
	return nil, fmt.Errorf("Asset %s not found", name)
}

// MustAsset is like Asset but panics when Asset would return an error.
// It simplifies safe initialization of global variables.
func MustAsset(name string) []byte {
	a, err := Asset(name)
	if err != nil {
		panic("asset: Asset(" + name + "): " + err.Error())
	}

	return a
}

// AssetInfo loads and returns the asset info for the given name.
// It returns an error if the asset could not be found or
// could not be loaded.
func AssetInfo(name string) (os.FileInfo, error) {
	cannonicalName := strings.Replace(name, "\\", "/", -1)
	if f, ok := _bindata[cannonicalName]; ok {
		a, err := f()
		if err != nil {
			return nil, fmt.Errorf("AssetInfo %s can't read by error: %v", name, err)
		}
		return a.info, nil
	}
	return nil, fmt.Errorf("AssetInfo %s not found", name)
}

// AssetNames returns the names of the assets.
func AssetNames() []string {
	names := make([]string, 0, len(_bindata))
	for name := range _bindata {
		names = append(names, name)
	}
	return names
}

// _bindata is a table, holding each asset generator, mapped to its name.
var _bindata = map[string]func() (*asset, error){
	"bootstrap.json.tmpl": bootstrapJsonTmpl,
}

// AssetDir returns the file names below a certain
// directory embedded in the file by go-bindata.
// For example if you run go-bindata on data/... and data contains the
// following hierarchy:
//     data/
//       foo.txt
//       img/
//         a.png
//         b.png
// then AssetDir("data") would return []string{"foo.txt", "img"}
// AssetDir("data/img") would return []string{"a.png", "b.png"}
// AssetDir("foo.txt") and AssetDir("notexist") would return an error
// AssetDir("") will return []string{"data"}.
func AssetDir(name string) ([]string, error) {
	node := _bintree
	if len(name) != 0 {
		cannonicalName := strings.Replace(name, "\\", "/", -1)
		pathList := strings.Split(cannonicalName, "/")
		for _, p := range pathList {
			node = node.Children[p]
			if node == nil {
				return nil, fmt.Errorf("Asset %s not found", name)
			}
		}
	}
	if node.Func != nil {
		return nil, fmt.Errorf("Asset %s not found", name)
	}
	rv := make([]string, 0, len(node.Children))
	for childName := range node.Children {
		rv = append(rv, childName)
	}
	return rv, nil
}

type bintree struct {
	Func     func() (*asset, error)
	Children map[string]*bintree
}
var _bintree = &bintree{nil, map[string]*bintree{
	"bootstrap.json.tmpl": &bintree{bootstrapJsonTmpl, map[string]*bintree{}},
}}

// RestoreAsset restores an asset under the given directory
func RestoreAsset(dir, name string) error {
	data, err := Asset(name)
	if err != nil {
		return err
	}
	info, err := AssetInfo(name)
	if err != nil {
		return err
	}
	err = os.MkdirAll(_filePath(dir, filepath.Dir(name)), os.FileMode(0755))
	if err != nil {
		return err
	}
	err = ioutil.WriteFile(_filePath(dir, name), data, info.Mode())
	if err != nil {
		return err
	}
	err = os.Chtimes(_filePath(dir, name), info.ModTime(), info.ModTime())
	if err != nil {
		return err
	}
	return nil
}

// RestoreAssets restores an asset under the given directory recursively
func RestoreAssets(dir, name string) error {
	children, err := AssetDir(name)
	// File
	if err != nil {
		return RestoreAsset(dir, name)
	}
	// Dir
	for _, child := range children {
		err = RestoreAssets(dir, filepath.Join(name, child))
		if err != nil {
			return err
		}
	}
	return nil
}

func _filePath(dir, name string) string {
	cannonicalName := strings.Replace(name, "\\", "/", -1)
	return filepath.Join(append([]string{dir}, strings.Split(cannonicalName, "/")...)...)
}

