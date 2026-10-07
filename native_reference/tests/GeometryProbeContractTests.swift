import XCTest
import UIKit

/// Synthetic UIKit fixtures; not measured system-sheet constants.
@MainActor final class GeometryProbeContractTests: XCTestCase {
    final class CornerAuditView: UIView {
        var queries: [UInt] = []
        override func effectiveRadius(corner: UIRectCorner) -> CGFloat {
            queries.append(corner.rawValue)
            return super.effectiveRadius(corner: corner)
        }
    }
    final class ShapeContentView: UIView {
        override class var layerClass: AnyClass { CAShapeLayer.self }
    }
    @MainActor struct Fixture {
        let window: UIWindow, presenter: UIView, container: UIView, clip: CornerAuditView, sheet: UIView, barrier: UIView
        func snapshot() -> [String: Any] {
            GeometryProbe.observe(presentedView: sheet, presentingView: presenter, window: window)
        }
    }
    func fixture() -> Fixture {
        let window = UIWindow(frame: CGRect(x:0,y:0,width:402,height:874))
        let presenter=UIView(frame:window.bounds);window.addSubview(presenter)
        let container=UIView(frame:window.bounds);window.addSubview(container)
        let barrier=UIView(frame:container.bounds);barrier.backgroundColor = .black;barrier.alpha=0.2
        container.addSubview(barrier)
        let clip=CornerAuditView(frame:CGRect(x:20,y:40,width:300,height:600));clip.clipsToBounds=true
        clip.cornerConfiguration = .corners(topLeftRadius:.fixed(7),topRightRadius:.fixed(11),bottomLeftRadius:.fixed(13),bottomRightRadius:.fixed(17))
        container.addSubview(clip)
        let sheet=UIView(frame:clip.bounds);clip.addSubview(sheet)
        let above=UIView(frame:container.bounds);above.backgroundColor = .black;above.alpha=0.2
        above.accessibilityIdentifier="_UIDimmingView";container.addSubview(above)
        return Fixture(window:window,presenter:presenter,container:container,clip:clip,sheet:sheet,barrier:barrier)
    }
    func candidate(_ result: [String: Any], _ id: String) throws -> [String: Any] {
        try XCTUnwrap((result["sheet_candidates"] as? [[String:Any]])?.first { $0["id"] as? String == id })
    }
    func testFourIndependentCornerQueriesPreserveLiteralOrdering() throws {
        let f=fixture();let clip=try candidate(f.snapshot(),"sheet.ancestor.1")
        let radii=try XCTUnwrap(clip["effective_radii_model"] as? [String:CGFloat])
        XCTAssertEqual(radii,["top_left":7,"top_right":11,"bottom_left":13,"bottom_right":17])
        XCTAssertEqual(f.clip.queries,[1,2,4,8],"Combined query returns a maximum and loses asymmetry")
        XCTAssertNotNil(clip["corner_configuration"])
    }
    func testClipSelectionUsesRelationshipNotPrivateName() throws {
        let f=fixture();f.clip.accessibilityIdentifier="nothing-to-do-with-clipping"
        let clip=try candidate(f.snapshot(),"sheet.ancestor.1")
        XCTAssertEqual(clip["clip_candidate"] as? Bool,true)
        let barriers=try XCTUnwrap(f.snapshot()["barrier_candidates"] as? [[String:Any]])
        XCTAssertEqual(barriers.map{$0["id"] as? String},["sheet.ancestor.2.below.0"])
        XCTAssertEqual(barriers.first?["selection"] as? String,"public_below_branch_containment_appearance_interaction")
        let generic=UIView(frame:f.clip.frame);generic.clipsToBounds=true
        f.container.insertSubview(generic,at:1);generic.addSubview(f.sheet);f.clip.removeFromSuperview()
        XCTAssertEqual(try candidate(f.snapshot(),"sheet.ancestor.1")["clip_candidate"] as? Bool,true)
    }
    func testAncestryIDsRemainStableAcrossAllocationAndUnrelatedWindowSibling() throws {
        let a=fixture();let b=fixture();b.window.insertSubview(UIView(),at:0)
        let expected=["sheet","sheet.ancestor.1","sheet.ancestor.2","sheet.ancestor.3"]
        for f in [a,b] {
            XCTAssertEqual((f.snapshot()["sheet_candidates"] as? [[String:Any]])?.compactMap{$0["id"] as? String},expected)
        }
    }
    func testRealMaskPathSerializesEveryElementAndNestedMasks() throws {
        let f=fixture();let mask=CAShapeLayer();mask.fillRule = .evenOdd
        let path=CGMutablePath();path.move(to:CGPoint(x:1,y:2));path.addLine(to:CGPoint(x:3,y:4))
        path.addQuadCurve(to:CGPoint(x:7,y:8),control:CGPoint(x:5,y:6))
        path.addCurve(to:CGPoint(x:13,y:14),control1:CGPoint(x:9,y:10),control2:CGPoint(x:11,y:12));path.closeSubpath()
        mask.path=path;mask.bounds=CGRect(x:0,y:0,width:30,height:40);mask.transform=CATransform3DMakeScale(2,3,1)
        let nested=CAShapeLayer();nested.path=CGPath(rect:CGRect(x:2,y:3,width:4,height:5),transform:nil);mask.mask=nested
        let child=CAShapeLayer();child.path=CGPath(ellipseIn:CGRect(x:1,y:1,width:8,height:6),transform:nil);mask.addSublayer(child)
        f.clip.layer.mask=mask
        let clip=try candidate(f.snapshot(),"sheet.ancestor.1")
        let model=try XCTUnwrap(clip["model"] as? [String:Any]);let exposed=try XCTUnwrap(model["mask"] as? [String:Any])
        XCTAssertEqual(exposed["fill_rule"] as? String,"even-odd")
        let elements=try XCTUnwrap(exposed["clipping_path"] as? [[String:Any]])
        XCTAssertEqual(elements.compactMap{$0["type"] as? String},["move","line","quad","cubic","close"])
        XCTAssertEqual(elements.compactMap{($0["points"] as? [[CGFloat]])?.count},[1,1,2,3,0])
        XCTAssertEqual(elements[2]["points"] as? [[CGFloat]],[[5,6],[7,8]])
        XCTAssertEqual(elements[3]["points"] as? [[CGFloat]],[[9,10],[11,12],[13,14]])
        XCTAssertNotNil((exposed["mask"] as? [String:Any])?["clipping_path"])
        XCTAssertNotNil((exposed["sublayers"] as? [[String:Any]])?.first?["clipping_path"])
        XCTAssertEqual((exposed["transform"] as? [CGFloat])?[0],2)
        XCTAssertEqual((exposed["transform"] as? [CGFloat])?[5],3)
    }
    func testShadowPathIsNeverPromotedToClipping() throws {
        let f=fixture();f.clip.layer.shadowPath=CGPath(rect:f.clip.bounds,transform:nil)
        let model=try XCTUnwrap(try candidate(f.snapshot(),"sheet.ancestor.1")["model"] as? [String:Any])
        XCTAssertTrue(model["clipping_path"] is NSNull)
        XCTAssertNotNil(model["shadow_path_diagnostic"])
        XCTAssertTrue(model["mask"] is NSNull)
    }
    func testOrdinaryShapeContentIsNotAClippingMask() throws {
        let f=fixture();let content=ShapeContentView(frame:f.clip.bounds)
        f.clip.addSubview(content);(content.layer as! CAShapeLayer).path=CGPath(rect:content.bounds,transform:nil)
        let result=GeometryProbe.observe(presentedView:content,presentingView:f.presenter,window:f.window)
        let model=try XCTUnwrap(try candidate(result,"sheet")["model"] as? [String:Any])
        XCTAssertTrue(model["clipping_path"] is NSNull)
        XCTAssertNotNil(model["shape_path_diagnostic"])
    }
    func testMaskOnlyCandidateDoesNotInventRectangularClipping() throws {
        let f=fixture();f.clip.clipsToBounds=false
        let mask=CAShapeLayer();mask.path=CGPath(ellipseIn:CGRect(x:0,y:0,width:90,height:80),transform:nil)
        f.clip.layer.mask=mask
        let result=f.snapshot();let clip=try candidate(result,"sheet.ancestor.1")
        XCTAssertEqual(clip["clip_candidate"] as? Bool,true)
        let envelope=try XCTUnwrap(result["ancestor_clip_envelope"] as? [String:Any])
        XCTAssertEqual(envelope["rect"] as? [String:CGFloat],["x":0,"y":0,"width":402,"height":874])
        XCTAssertNotNil((clip["model"] as? [String:Any])?["mask"])
    }
    func testNestedPublicClippingDescendantIsNotMissed() throws {
        let f=fixture();let content=UIView(frame:f.sheet.bounds);f.sheet.addSubview(content)
        let clip=UIView(frame:CGRect(x:0,y:0,width:90,height:80));clip.clipsToBounds=true
        clip.cornerConfiguration = .corners(radius:.fixed(6));content.addSubview(clip)
        let observed=try candidate(f.snapshot(),"sheet.child.0.child.0")
        XCTAssertEqual(observed["clip_candidate"] as? Bool,true)
        XCTAssertEqual(observed["effective_radii_model"] as? [String:CGFloat],["top_left":6,"top_right":6,"bottom_left":6,"bottom_right":6])
    }
    func testClipEnvelopeAndPresenterObservationAreExplicitlyDiagnostic() throws {
        let f=fixture();f.presenter.layer.anchorPoint=CGPoint(x:0.25,y:0.75)
        f.presenter.layer.transform=CATransform3DMakeScale(0.8,0.9,1)
        let result=f.snapshot()
        XCTAssertEqual(result["accepted"] as? Bool,false)
        let envelope=try XCTUnwrap(result["ancestor_clip_envelope"] as? [String:Any])
        XCTAssertEqual(envelope["kind"] as? String,"axis_aligned_rect_intersection_not_contour")
        XCTAssertEqual(envelope["rect"] as? [String:CGFloat],["x":20,"y":40,"width":300,"height":600])
        let presenters=try XCTUnwrap(result["presenter_candidates"] as? [[String:Any]])
        let model=try XCTUnwrap(presenters.first?["model"] as? [String:Any])
        XCTAssertEqual(model["anchor"] as? [CGFloat],[0.25,0.75])
        XCTAssertEqual((model["transform"] as? [CGFloat])?[0],0.8)
        XCTAssertEqual((model["transform"] as? [CGFloat])?[5],0.9)
        XCTAssertTrue(presenters.first?["presentation"] is NSNull)
    }
}
