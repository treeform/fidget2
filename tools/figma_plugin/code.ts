const visit = (node) => {
	var obj = {};
    console.log(Object.getOwnPropertyDescriptors(node.__proto__));

    obj["id"] = node.id
    obj["name"] = node.name
    obj["kind"] = node.kind
    obj["opacity"] = node.opacity
    obj["visible"] = node.visible
    obj["blendMode"] = node.blendMode
    obj["prototypeStartNodeID"] = node.prototypeStartNodeID
    obj["prototypeDevice"] = node.prototypeDevice

    obj["relativeTransform"] = node.relativeTransform
    obj["constraints"] = node.constraints
    obj["layoutAlign"] = node.layoutAlign
    obj["clipsContent"] = node.clipsContent
    obj["background"] = node.background
    obj["fills"] = node.fills
    obj["strokes"] = node.strokes
    obj["strokeWeight"] = node.strokeWeight
    obj["strokeAlign"] = node.strokeAlign
    obj["backgroundColor"] = node.backgroundColor
    obj["layoutGrids"] = node.layoutGrids
    obj["layoutMode"] = node.layoutMode
    obj["itemSpacing"] = node.itemSpacing
    obj["effects"] = node.effects
    obj["isMask"] = node.isMask
    obj["cornerRadius"] = node.cornerRadius
    obj["rectangleCornerRadii"] = node.rectangleCornerRadii
    obj["characters"] = node.characters
    obj["style"] = node.style
    obj["fillGeometry"] = node.fillGeometry
    obj["strokeGeometry"] = node.strokeGeometry
    obj["booleanOperation"] = node.booleanOperation

    obj["absoluteBoundingBox"] = {
        "x": node.x,
        "y": node.y,
        "w": node.width,
        "h": node.height
    }

    obj["size"] = {
        "x": node.width,
        "y": node.height
    }

    obj["children"] = [];
    if (node.children != undefined){
        for (var c of node.children) {
            obj["children"].push(visit(c))
        }
    }
    return obj;
};

var text = JSON.stringify(visit(figma.currentPage), null, 2)

figma.showUI(`
<span style="white-space:pre-wrap;font-family:monospace">${text}</span>
`, { width: 500, height: 600 });
