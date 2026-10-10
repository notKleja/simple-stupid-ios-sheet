import UIKit
import QuartzCore

/// Observations, not a resolved system clipping contour or accepted profile.
/// IDs depend on public ancestry/order, never implementation class names.
@MainActor enum GeometryProbe {
    private static func rectangle(_ r: CGRect) -> [String:CGFloat] {
        ["x":r.origin.x,"y":r.origin.y,"width":r.width,"height":r.height]
    }
    private static func transform(_ t: CATransform3D) -> [CGFloat] {
        [t.m11,t.m12,t.m13,t.m14,t.m21,t.m22,t.m23,t.m24,t.m31,t.m32,t.m33,t.m34,t.m41,t.m42,t.m43,t.m44]
    }
    private static func path(_ value: CGPath?) -> Any {
        guard let value else { return NSNull() }
        var elements:[[String:Any]]=[]
        value.applyWithBlock { pointer in
            let element=pointer.pointee
            let kind:String, count:Int
            switch element.type {
            case .moveToPoint: kind="move";count=1
            case .addLineToPoint: kind="line";count=1
            case .addQuadCurveToPoint: kind="quad";count=2
            case .addCurveToPoint: kind="cubic";count=3
            case .closeSubpath: kind="close";count=0
            @unknown default: kind="unknown";count=0
            }
            elements.append(["type":kind,"points":(0..<count).map { [element.points[$0].x,element.points[$0].y] }])
        }
        return elements
    }
    private static func layer(_ value: CALayer, depth: Int=0, maskTree: Bool=false) -> [String:Any] {
        guard depth<32 else { return ["unavailable":"Layer/mask recursion exceeds32; not silently complete"] }
        var result:[String:Any] = ["bounds":rectangle(value.bounds),"frame_in_parent":rectangle(value.frame),
            "position":[value.position.x,value.position.y],"anchor":[value.anchorPoint.x,value.anchorPoint.y],
            "transform":transform(value.transform),"sublayer_transform":transform(value.sublayerTransform),
            "radius":value.cornerRadius,"curve":value.cornerCurve.rawValue,"masked_corners":value.maskedCorners.rawValue,
            "clips":value.masksToBounds,"opacity":value.opacity,"hidden":value.isHidden,
            "background_alpha":value.backgroundColor?.alpha as Any? ?? NSNull(),
            "clipping_path":NSNull(),"shadow_path_diagnostic":path(value.shadowPath),
            "mask":value.mask.map { layer($0,depth:depth+1,maskTree:true) } as Any? ?? NSNull()]
        if let shape=value as? CAShapeLayer {
            result[maskTree ? "clipping_path" : "shape_path_diagnostic"]=path(shape.path)
            result["fill_rule"]=shape.fillRule.rawValue
            result["path_role"]=maskTree ? "mask_component_not_complete_contour" : "shape_content_diagnostic"
        }
        // A mask can contain shape sublayers as well as another mask.
        result["sublayers"]=maskTree ? (value.sublayers ?? []).map { layer($0,depth:depth+1,maskTree:true) } : []
        return result
    }
    private static func node(_ view: UIView, id: String, window: UIWindow,
                             samples:[ObjectIdentifier:CALayer]) -> [String:Any] {
        let presentation=samples[ObjectIdentifier(view.layer)] ?? view.layer.presentation()
        var result:[String:Any] = ["id":id,"selection":"public_relationship",
            "class_diagnostic_only":NSStringFromClass(type(of:view)),
            "model_window_rect":rectangle(view.convert(view.bounds,to:window)),
            "clip_candidate":view.clipsToBounds || view.layer.mask != nil || view.mask != nil,
            "interaction_enabled":view.isUserInteractionEnabled,"model":layer(view.layer),
            "view_mask_model":view.mask.map { layer($0.layer,maskTree:true) } as Any? ?? NSNull(),
            "presentation":presentation.map { layer($0) } as Any? ?? NSNull(),
            "presentation_source":samples[ObjectIdentifier(view.layer)] != nil ? "coherent_window_tree" : (presentation == nil ? "unavailable" : "independent_public_presentation_copy"),
            "presentation_unavailable_reason":"No presentation sample when null; model is not substituted"]
        if #available(iOS 26.0, *) {
            result["corner_configuration"]=["present":true,"description_diagnostic_only":String(describing:view.cornerConfiguration)]
            // Four independent calls are necessary: a combined mask returns a maximum.
            result["effective_radii_model"]=["top_left":view.effectiveRadius(corner:.topLeft),
                "top_right":view.effectiveRadius(corner:.topRight),
                "bottom_left":view.effectiveRadius(corner:.bottomLeft),
                "bottom_right":view.effectiveRadius(corner:.bottomRight)]
        } else {
            result["corner_configuration"]=NSNull();result["effective_radii_model"]=NSNull()
            result["radii_unavailable_reason"]="Public effectiveRadius API requires iOS26+"
        }
        return result
    }
    static func observe(presentedView: UIView, presentingView: UIView, window: UIWindow,
                        presentationSamples:[ObjectIdentifier:CALayer]=[:],
                        presentationWindowRect:((CALayer)->CGRect?)?=nil) -> [String:Any] {
        var sheets:[[String:Any]]=[], presenters:[[String:Any]]=[], barriers:[[String:Any]]=[]
        var modelEnvelope=window.bounds, presentationEnvelope=window.bounds
        var presentationEnvelopeAvailable=presentationWindowRect != nil
        var current:UIView?=presentedView;var depth=0
        while let view=current {
            let id=depth==0 ? "sheet" : "sheet.ancestor.\(depth)"
            var observed=node(view,id:id,window:window,samples:presentationSamples)
            observed["ancestor_depth"]=depth;sheets.append(observed)
            // An arbitrary mask is not the view-bounds rectangle. Its components
            // are serialized separately; never invent a rectangular intersection.
            if view.clipsToBounds || view.layer.masksToBounds {
                modelEnvelope=modelEnvelope.intersection(view.convert(view.bounds,to:window))
                if let r=presentationWindowRect?(view.layer) { presentationEnvelope=presentationEnvelope.intersection(r) }
                else { presentationEnvelopeAvailable=false }
            }
            if view === window { break }
            if let parent=view.superview, let branchIndex=parent.subviews.firstIndex(where:{$0 === view}) {
                for (index,sibling) in parent.subviews.prefix(branchIndex).enumerated() {
                    let r=sibling.convert(sibling.bounds,to:window)
                    let alpha=sibling.backgroundColor?.cgColor.alpha ?? sibling.layer.backgroundColor?.alpha ?? 0
                    let hasAppearance=alpha>0 || sibling.alpha<1 || sibling.layer.opacity<1
                    guard !sibling.isHidden, sibling.alpha>0, hasAppearance,
                        r.contains(presentedView.convert(presentedView.bounds,to:window)) else { continue }
                    var candidate=node(sibling,id:"sheet.ancestor.\(depth+1).below.\(index)",window:window,samples:presentationSamples)
                    candidate["selection"]="public_below_branch_containment_appearance_interaction"
                    candidate["contains_presented_model_rect"]=true
                    candidate["effective_barrier_alpha"]=NSNull()
                    candidate["unavailable_reason"]="Candidate only; appearance/interaction do not prove a classified dimming surface"
                    barriers.append(candidate)
                }
            }
            current=view.superview;depth+=1
        }
        // UIKit may expose a wrapper as presentedView, with its actual content
        // clipping view below it. Public subview relationships cover that case.
        var descendantTraversalTruncated=false
        func descendants(_ parent:UIView, _ parentID:String, _ level:Int) {
            guard level<64 else { descendantTraversalTruncated=true;return }
            for (index,child) in parent.subviews.enumerated() {
                let id="\(parentID).child.\(index)"
                if child.clipsToBounds || child.layer.masksToBounds || child.layer.mask != nil || child.mask != nil {
                    var observed=node(child,id:id,window:window,samples:presentationSamples)
                    observed["relationship"]="public_descendant_clip_candidate"
                    observed["parent_id"]=parentID
                    observed["presentation_window_rect"]=presentationWindowRect?(child.layer).map(rectangle) as Any? ?? NSNull()
                    sheets.append(observed)
                }
                descendants(child,id,level+1)
            }
        }
        descendants(presentedView,"sheet",0)
        current=presentingView;depth=0
        while let view=current {
            presenters.append(node(view,id:depth==0 ? "presenter" : "presenter.ancestor.\(depth)",window:window,samples:presentationSamples))
            if view === window { break };current=view.superview;depth+=1
        }
        func envelope(_ r:CGRect) -> Any { r.isNull ? NSNull() : rectangle(r) }
        return ["schema_version":1,"accepted":false,"scope":"public_geometry_diagnostic_not_contour",
            "sheet_candidates":sheets,"barrier_candidates":barriers,"presenter_candidates":presenters,
            "descendant_traversal_truncated":descendantTraversalTruncated,
            "ancestor_clip_envelope":["kind":"axis_aligned_rect_intersection_not_contour","source":"model", "rect":envelope(modelEnvelope)],
            "presentation_ancestor_clip_envelope":["kind":"axis_aligned_rect_intersection_not_contour","source":"coherent_window_projection",
                "rect":presentationEnvelopeAvailable ? envelope(presentationEnvelope) : NSNull(),
                "unavailable_reason":"No complete coherent presentation projection when null"],
            "limitations":["Effective UIView radii describe current model configuration, not guaranteed interpolated display radii",
                "Continuous-corner scalar/curve does not export an exact vector contour",
                "Shadow paths are diagnostic only; layer-only subtrees may contain additional clips",
                "Rect envelopes intersect rectangular clips only, not mask/continuous-curve coverage",
                "No canonical radius, contour, barrier alpha or presenter wrapper has been accepted"]]
    }
}
