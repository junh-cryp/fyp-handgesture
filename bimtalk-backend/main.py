import math
from typing import List, Dict, Optional, Any
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from supabase import create_client, Client

app = FastAPI(title="BimTalk Gesture Recognition Engine")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Supabase Config ---
SUPABASE_URL = "https://jjgpymogvgdcjatyzuct.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpqZ3B5bW9ndmdkY2phdHl6dWN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwNjEwMDAsImV4cCI6MjEwNTYzNzAwMH0.0FRpMYgiJtr25n-apfCbNcwGiuquziT0y6jqI60Cm8o"
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Map of BIM signs that share the same gesture/motion (synonyms or twin signs)
GESTURE_SYNONYMS: Dict[str, List[str]] = {
    "ANDA": ["ANDA", "AWAK"],
    "AWAK": ["ANDA", "AWAK"],
    "BELI": ["BELI", "BELANJA"],
    "BELANJA": ["BELI", "BELANJA"],
}

class Landmark(BaseModel):
    x: float
    y: float
    z: Optional[float] = 0.0

class HandData(BaseModel):
    landmarks: List[Landmark]

class SizeData(BaseModel):
    width: float
    height: float

class GestureRequest(BaseModel):
    hands: List[HandData]
    posePoints: Optional[Dict[str, Landmark]] = None
    imageSize: Optional[SizeData] = None

class GestureResult(BaseModel):
    word: str
    matchScore: float

class GestureDebugInfo(BaseModel):
    fingerStatus: str
    orientation: str
    tipPos: str
    direction: str
    extra: str = ""

class Offset:
    def __init__(self, dx: float, dy: float):
        self.dx = float(dx)
        self.dy = float(dy)

    def __sub__(self, other: 'Offset') -> 'Offset':
        return Offset(self.dx - other.dx, self.dy - other.dy)

    def __add__(self, other: 'Offset') -> 'Offset':
        return Offset(self.dx + other.dx, self.dy + other.dy)

    @property
    def distance(self) -> float:
        return math.sqrt(self.dx * self.dx + self.dy * self.dy)

    def __repr__(self):
        return f"Offset({self.dx:.4f}, {self.dy:.4f})"


class HandState:
    def __init__(
        self,
        points: List[Offset],
        is_thumb_up: bool,
        is_index_up: bool,
        is_middle_up: bool,
        is_ring_up: bool,
        is_pinky_up: bool,
        is_vertical: bool,
        is_horizontal: bool,
        move_dir: str,
        thumb_vertical: bool,
        thumb_horizontal: bool,
        index_vertical: bool,
        index_horizontal: bool,
        pinky_vertical: bool,
        pinky_horizontal: bool,
        middle_vertical: bool = False,
        middle_horizontal: bool = False,
        ring_vertical: bool = False,
        ring_horizontal: bool = False,
    ):
        self.points = points
        self.is_thumb_up = is_thumb_up
        self.is_index_up = is_index_up
        self.is_middle_up = is_middle_up
        self.is_ring_up = is_ring_up
        self.is_pinky_up = is_pinky_up
        self.is_vertical = is_vertical
        self.is_horizontal = is_horizontal
        self.move_dir = move_dir
        self.thumb_vertical = thumb_vertical
        self.thumb_horizontal = thumb_horizontal
        self.index_vertical = index_vertical
        self.index_horizontal = index_horizontal
        self.pinky_vertical = pinky_vertical
        self.pinky_horizontal = pinky_horizontal
        self.middle_vertical = middle_vertical
        self.middle_horizontal = middle_horizontal
        self.ring_vertical = ring_vertical
        self.ring_horizontal = ring_horizontal

    @classmethod
    def from_hand(cls, hand: HandData) -> 'HandState':
        raw = hand.landmarks

        points = [Offset(p.y, 1.0 - p.x) for p in raw]

        def dist(a: Offset, b: Offset) -> float:
            return (a - b).distance

        hand_scale = dist(points[0], points[9])
        if hand_scale < 0.05:
            hand_scale = 0.2

        def is_ext(tip: int, joint: int) -> bool:
            return dist(points[tip], points[0]) > dist(points[joint], points[0]) + (hand_scale * 0.1)

        h_dist = abs(points[9].dx - points[0].dx)
        v_dist = abs(points[9].dy - points[0].dy)

        vertical = v_dist > h_dist * 1.2
        horizontal = h_dist > v_dist * 1.2

        tx_h = abs(points[4].dx - points[2].dx)
        ty_v = abs(points[4].dy - points[2].dy)
        thumb_v = ty_v > tx_h * 1.0
        thumb_h = tx_h > ty_v * 1.0

        ix_h = abs(points[8].dx - points[5].dx)
        iy_v = abs(points[8].dy - points[5].dy)
        index_v = iy_v > ix_h * 1.0
        index_h = ix_h > iy_v * 1.0

        px_h = abs(points[20].dx - points[17].dx)
        py_v = abs(points[20].dy - points[17].dy)
        pinky_v = py_v > px_h * 1.1
        pinky_h = px_h > py_v * 1.1

        mx_h = abs(points[12].dx - points[9].dx)
        my_v = abs(points[12].dy - points[9].dy)
        middle_v = my_v > mx_h * 1.0
        middle_h = mx_h > my_v * 1.0

        rx_h = abs(points[16].dx - points[13].dx)
        ry_v = abs(points[16].dy - points[13].dy)
        ring_v = ry_v > rx_h * 1.0
        ring_h = rx_h > ry_v * 1.0

        move_dir = "UNKNOWN"
        if vertical:
            move_dir = "UP" if points[9].dy < points[0].dy else "DOWN"
        elif horizontal:
            move_dir = "RIGHT" if points[9].dx < points[0].dx else "LEFT"

        return cls(
            points=points,
            is_thumb_up=dist(points[4], points[5]) > (hand_scale * 0.4),
            is_index_up=is_ext(8, 6),
            is_middle_up=is_ext(12, 10),
            is_ring_up=is_ext(16, 14),
            is_pinky_up=is_ext(20, 18),
            is_vertical=vertical,
            is_horizontal=horizontal,
            move_dir=move_dir,
            thumb_vertical=thumb_v,
            thumb_horizontal=thumb_h,
            index_vertical=index_v,
            index_horizontal=index_h,
            pinky_vertical=pinky_v,
            pinky_horizontal=pinky_h,
            middle_vertical=middle_v,
            middle_horizontal=middle_h,
            ring_vertical=ring_v,
            ring_horizontal=ring_h,
        )


MINIMUM_MATCH_SCORE = 0.70

def calculate_rule_score(conditions: List[bool]) -> float:
    if not conditions:
        return 0.0
    passed = sum(1 for condition in conditions if condition)
    return passed / len(conditions)

from gesture_logic import check_single_hand_gestures, check_two_hand_gestures

@app.get("/")
def home():
    return {"status": "FastAPI Server is running successfully!"}

@app.post("/analyze-gesture")
async def analyze_gesture(payload: GestureRequest):
    if not payload.hands:
        return []

    h_states = [HandState.from_hand(h) for h in payload.hands]
    single_candidates = []
    two_candidates = []

    def p2s(p: Landmark) -> Offset:
        if payload.imageSize and payload.imageSize.width > 0 and payload.imageSize.height > 0:
            return Offset(p.y / payload.imageSize.height, 1.0 - (p.x / payload.imageSize.width))
        return Offset(p.y, 1.0 - p.x)

    def add_single(word: str, strict: List[bool], scoring: Optional[List[bool]] = None):
        if scoring is None:
            scoring = []
        if not all(strict):
            return
        score = calculate_rule_score(strict + scoring)
        if score >= MINIMUM_MATCH_SCORE:
            single_candidates.append({"word": word, "matchScore": score})

    def add_two(word: str, strict: List[bool], scoring: Optional[List[bool]] = None):
        if scoring is None:
            scoring = []
        if not all(strict):
            return
        score = calculate_rule_score(strict + scoring)
        if score >= MINIMUM_MATCH_SCORE:
            two_candidates.append({"word": word, "matchScore": score})

    pose = payload.posePoints or {}

    # Run gesture checks from gesture_logic.py
    check_single_hand_gestures(h_states, payload, p2s, pose, add_single)
    check_two_hand_gestures(h_states, payload, p2s, pose, add_two)

    # Candidates sorting & deduplication
    final_candidates = two_candidates if (len(h_states) == 2 and two_candidates) else (two_candidates + single_candidates)
    final_candidates.sort(key=lambda x: x["matchScore"], reverse=True)

    seen = set()
    unique_candidates = []
    
    # Expand synonyms and deduplicate
    for c in final_candidates:
        word_upper = c["word"].upper()
        synonyms = GESTURE_SYNONYMS.get(word_upper)

        if synonyms:
            for syn in synonyms:
                if syn.upper() not in seen:
                    seen.add(syn.upper())
                    unique_candidates.append({
                        "word": syn,
                        "matchScore": c["matchScore"]
                    })
        else:
            if word_upper not in seen:
                seen.add(word_upper)
                unique_candidates.append(c)

    # Query Supabase for candidate details
    results = []
    for cand in unique_candidates:
        try:
            response = supabase.table("gestures").select("*").ilike("name_bm", cand["word"]).execute()
            if response.data:
                db_data = response.data[0]
                results.append({
                    "word": cand["word"],
                    "score": cand["matchScore"],
                    "image_url": db_data.get("image_url") or db_data.get("sign_image_url") or "",
                    "description_bm": db_data.get("description_bm"),
                    "description_en": db_data.get("description_en")
                })
            else:
                results.append({
                    "word": cand["word"],
                    "score": cand["matchScore"],
                    "image_url": "",
                    "description_bm": None,
                    "description_en": None
                })
        except Exception as e:
            print(f"Supabase Query Error for {cand['word']}: {e}")
            results.append({
                "word": cand["word"],
                "score": cand["matchScore"],
                "image_url": "",
                "description_bm": None,
                "description_en": None
            })

    return results


@app.post("/debug-gesture")
def get_debug_info_endpoint(payload: GestureRequest):
    debug_list = []
    pose = payload.posePoints or {}
    l_eye = pose.get("leftEye")
    r_eye = pose.get("rightEye")
    lm = pose.get("leftMouth")
    rm = pose.get("rightMouth")
    ns = pose.get("nose")

    def p2s(p: Landmark) -> Offset:
        if payload.imageSize and payload.imageSize.width > 0 and payload.imageSize.height > 0:
            return Offset(p.y / payload.imageSize.height, 1.0 - (p.x / payload.imageSize.width))
        return Offset(p.y, 1.0 - p.x)

    for hand in payload.hands:
        state = HandState.from_hand(hand)
        extra = ""
        if payload.imageSize:
            if lm and rm:
                m = Offset((p2s(lm).dx + p2s(rm).dx) / 2, (p2s(lm).dy + p2s(rm).dy) / 2)
                d = (state.points[8] - m).distance
                extra = f"MDist:{d:.2f}"
            elif ns:
                p_nose = p2s(ns)
                m = Offset(p_nose.dx, p_nose.dy + 0.07)
                d = (state.points[8] - m).distance
                extra = f"NDist:{d:.2f}"
            elif l_eye and r_eye:
                p_l_eye = p2s(l_eye)
                p_r_eye = p2s(r_eye)
                eye_mid = Offset((p_l_eye.dx + p_r_eye.dx) / 2, (p_l_eye.dy + p_r_eye.dy) / 2)
                d = (state.points[4] - eye_mid).distance
                extra = f"EDist:{d:.2f}"

        p_dir = (
            ("P-UP" if state.points[20].dy < state.points[17].dy else "P-DN")
            if state.pinky_vertical
            else ("P-HZ" if state.pinky_horizontal else "P-SL")
        )
        p_ext = (state.points[20] - state.points[17]).distance

        debug_list.append({
            "fingerStatus": f"T:{1 if state.is_thumb_up else 0} I:{1 if state.is_index_up else 0} M:{1 if state.is_middle_up else 0} R:{1 if state.is_ring_up else 0} P:{1 if state.is_pinky_up else 0}",
            "orientation": "Vertical" if state.is_vertical else ("Horizontal" if state.is_horizontal else "Slanted"),
            "tipPos": f"X:{state.points[8].dx:.2f} Y:{state.points[8].dy:.2f}",
            "direction": f"{state.move_dir} {p_dir} E:{p_ext:.2f}",
            "extra": extra,
        })
    return debug_list
