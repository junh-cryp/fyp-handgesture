from typing import List, Dict, Optional, Any
from main import Offset

def check_single_hand_gestures(h_states: List[Any], payload: Any, p2s: Any, pose: Dict[str, Any], add_single: Any):
    l_sh = pose.get("leftShoulder")
    r_sh = pose.get("rightShoulder")
    l_mouth = pose.get("leftMouth")
    r_mouth = pose.get("rightMouth")
    nose = pose.get("nose")
    l_eye = pose.get("leftEye")
    r_eye = pose.get("rightEye")

    # Single Hand Signs
    for state in h_states:
        # 1. Open Palm Gesture (HAI)
        above_shoulder = False
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2
            if state.points[0].dy < sh_v:
                above_shoulder = True

        add_single("HAI", [
            not state.is_thumb_up, state.is_index_up, state.is_middle_up, state.is_ring_up, state.is_pinky_up,
            state.index_vertical,
            above_shoulder,
        ], [
            state.points[8].dy < state.points[5].dy,  # Index tip pointing UP
        ])

        # 2. PEACE (Index + Middle Up, Above Shoulder)
        above_shoulder = False
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2
            if state.points[0].dy < sh_v:
                above_shoulder = True

        add_single("PEACE", [
            state.is_index_up, state.is_middle_up,
            not state.is_ring_up, not state.is_pinky_up,
            state.index_vertical,
        ], [
            state.points[8].dy < state.points[5].dy,  # Index tip higher than knuckle
            above_shoulder,
        ])

        # 3. BAGUS (Thumb Vertical Up, Above Shoulder)
        above_shoulder = False
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2
            if state.points[0].dy < sh_v:
                above_shoulder = True

        add_single("BAGUS", [
            state.is_thumb_up,
            not state.is_index_up, not state.is_middle_up, not state.is_ring_up, not state.is_pinky_up,
            state.thumb_vertical,
            state.index_horizontal,
        ], [
            state.points[4].dy < state.points[2].dy,  # Thumb tip higher than thumb knuckle
            state.points[8].dx > state.points[5].dx,  # Index pointing towards X=1 (Left)
            above_shoulder,
        ])

        add_single("MANA", [
            state.is_index_up,
            not state.is_thumb_up, not state.is_middle_up, not state.is_ring_up, not state.is_pinky_up,
            state.index_vertical,
            above_shoulder,
        ])

        # 4. MINUM (Thumb near mouth)
        if payload.imageSize:
            p_mouth = None
            if l_mouth and r_mouth:
                p_mouth = Offset((p2s(l_mouth).dx + p2s(r_mouth).dx) / 2, (p2s(l_mouth).dy + p2s(r_mouth).dy) / 2)
            elif nose:
                p_nose = p2s(nose)
                p_mouth = Offset(p_nose.dx, p_nose.dy + 0.07)

            if p_mouth is not None:
                d = (state.points[4] - p_mouth).distance
                add_single("MINUM", [
                    state.is_thumb_up,
                    not state.is_index_up, not state.is_middle_up, not state.is_ring_up, not state.is_pinky_up,
                    state.thumb_horizontal,
                ], [
                    state.points[4].dx > state.points[2].dx,  # Thumb tip pointing towards X=1 (Left)
                    d < 0.40,  # Relaxed distance
                    above_shoulder
                ])

        # 7. Berhenti (Closed Fist, Above Shoulder)
        above_shoulder = False
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2
            if state.points[0].dy < sh_v:
                above_shoulder = True

        add_single("Berhenti", [
            not state.is_thumb_up, not state.is_index_up, not state.is_middle_up, not state.is_ring_up, not state.is_pinky_up,
            state.is_vertical,
        ], [
            state.move_dir == "UP",  # Knuckles are above the wrist
            above_shoulder,
        ])

        # 8. BELI / (Thumb Vertical + Index Horizontal, Below Shoulder)
        below_shoulder = False
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2
            if state.points[0].dy > sh_v:
                below_shoulder = True

        strict_beli = [
            state.is_thumb_up, state.is_index_up,
            not state.is_middle_up, not state.is_ring_up, not state.is_pinky_up,
            state.thumb_vertical,
            state.index_horizontal,
        ]
        score_beli = [
            state.points[4].dy < state.points[2].dy,  # Thumb pointing UP
            below_shoulder,
        ]
        add_single("BELI", strict_beli, score_beli)
        

        # BELANJA
        below_shoulder = False
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2
            if state.points[0].dy > sh_v:
                below_shoulder = True

        strict_beli = [
            state.is_thumb_up, state.is_index_up,
            not state.is_middle_up, not state.is_ring_up, not state.is_pinky_up,
            state.thumb_vertical,
            state.index_horizontal,
        ]
        score_beli = [
            state.points[4].dy < state.points[2].dy,  # Thumb pointing UP
            below_shoulder,
        ]
        add_single("BELANJA", strict_beli, score_beli)

        # 12. TIDAK BOLEH (Pinky only, Horizontal, Below Shoulder)
        below_shoulder = False
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2
            if state.points[0].dy > sh_v:
                below_shoulder = True

        add_single("TIDAK BOLEH", [
            state.is_pinky_up, not state.is_thumb_up, not state.is_index_up, not state.is_middle_up, not state.is_ring_up,
            state.pinky_horizontal,
        ], [
            below_shoulder,
        ])

        add_single("SAMA-SAMA", [
            state.is_pinky_up, state.is_thumb_up, not state.is_index_up, not state.is_middle_up, not state.is_ring_up,
            state.pinky_horizontal, state.thumb_vertical,
        ], [
            below_shoulder,
        ])

        # TERIMA KASIH & SALAH
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2
            p_mouth = None
            if l_mouth and r_mouth:
                p_mouth = Offset((p2s(l_mouth).dx + p2s(r_mouth).dx) / 2, (p2s(l_mouth).dy + p2s(r_mouth).dy) / 2)
            elif nose:
                p_nose = p2s(nose)
                p_mouth = Offset(p_nose.dx, p_nose.dy + 0.07)

            if p_mouth is not None:
                d_mouth = (state.points[8] - p_mouth).distance
                add_single("TERIMA KASIH", [
                    state.is_thumb_up, state.is_index_up, state.is_middle_up, state.is_ring_up, state.is_pinky_up,
                    state.index_vertical, state.pinky_vertical,
                    d_mouth < 0.45,  # Strict position requirement: must be near mouth
                    state.points[0].dy > sh_v,
                ], [
                    state.points[8].dy < state.points[5].dy,  # Index tip pointing UP
                    state.points[20].dy < state.points[17].dy,  # Pinky tip pointing UP
                    state.points[8].dy < sh_v,  # Index tip above shoulder
                ])

                d_mouth_pinky = (state.points[20] - p_mouth).distance
                add_single("SALAH", [
                    state.is_thumb_up, not state.is_index_up, not state.is_middle_up, not state.is_ring_up, state.is_pinky_up,
                    state.index_vertical, state.pinky_vertical,
                    d_mouth_pinky < 0.45,  # Strict position requirement: must be near mouth
                    state.points[0].dy > sh_v,  # below shoulder
                ], [
                    state.points[20].dy < state.points[17].dy,  # Pinky tip pointing UP
                    state.points[20].dy < sh_v,  # Pinky tip above shoulder
                ])

        # 19. APA GUNANYA (4 fingers near mouth, thumb folded)
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2
            p_mouth = None
            if l_mouth and r_mouth:
                p_mouth = Offset((p2s(l_mouth).dx + p2s(r_mouth).dx) / 2, (p2s(l_mouth).dy + p2s(r_mouth).dy) / 2)
            elif nose:
                p_nose = p2s(nose)
                p_mouth = Offset(p_nose.dx, p_nose.dy + 0.07)

            if p_mouth is not None:
                d_mouth = (state.points[8] - p_mouth).distance
                add_single("APA GUNANYA ?", [
                    not state.is_thumb_up, state.is_index_up, state.is_middle_up, state.is_ring_up, state.is_pinky_up,
                    state.index_vertical, state.pinky_vertical,
                    d_mouth < 0.45,  # Strict position requirement: must be near mouth
                    state.points[0].dy >= sh_v,
                ], [
                    state.points[8].dy < state.points[5].dy,  # Index tip pointing UP
                    state.points[20].dy < state.points[17].dy,  # Pinky tip pointing UP
                    state.points[8].dy < sh_v,  # Index tip above shoulder
                ])

        # 20. OH! BEGITU RUPANYA (Open Palm near chest, Index Horizontal)
        if l_sh and r_sh and payload.imageSize:
            p_l_sh = p2s(l_sh)
            p_r_sh = p2s(r_sh)
            s_mid = Offset((p_l_sh.dx + p_r_sh.dx) / 2, (p_l_sh.dy + p_r_sh.dy) / 2)
            chest = Offset(s_mid.dx, s_mid.dy + 0.20)
            d_chest = (state.points[9] - chest).distance

            add_single("OH! BEGITU RUPANYA", [
                state.is_thumb_up, state.is_index_up, state.is_middle_up, state.is_ring_up, state.is_pinky_up,
                state.thumb_vertical,
                state.index_horizontal,
                d_chest < 0.45,  # Relaxed distance
            ], [
                state.points[4].dy < state.points[2].dy,  # Thumb pointing UP
            ])

        # 9. DIAM (Index Up near Mouth)
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2
            p_mouth = None
            if l_mouth and r_mouth:
                p_mouth = Offset((p2s(l_mouth).dx + p2s(r_mouth).dx) / 2, (p2s(l_mouth).dy + p2s(r_mouth).dy) / 2)
            elif nose:
                p_nose = p2s(nose)
                p_mouth = Offset(p_nose.dx, p_nose.dy + 0.07)

            if p_mouth is not None:
                d_mouth = (state.points[8] - p_mouth).distance
                pointing_up = state.points[8].dy < state.points[5].dy
                add_single("DIAM", [
                    state.is_index_up,
                    not state.is_thumb_up, not state.is_middle_up, not state.is_ring_up, not state.is_pinky_up,
                    state.index_vertical,
                    d_mouth < 0.40,  # Strict position requirement: must be near mouth
                ], [
                    pointing_up,
                    state.points[8].dy < sh_v,
                ])

        # 10. SAYA
        if l_sh and r_sh and payload.imageSize:
            p_l_sh = p2s(l_sh)
            p_r_sh = p2s(r_sh)
            sh_v = (p_l_sh.dy + p_r_sh.dy) / 2
            chest = Offset((p_l_sh.dx + p_r_sh.dx) / 2, sh_v + 0.15)
            d_chest = (state.points[8] - chest).distance
            add_single("SAYA", [
                state.is_index_up, not state.is_thumb_up, not state.is_middle_up, not state.is_ring_up, not state.is_pinky_up,
                state.index_horizontal,
                state.points[8].dx > state.points[5].dx,  # Must point towards X=1 (Left)
                state.points[8].dy > sh_v,  # must below shoulder
            ], [
                d_chest < 0.45,  # Relaxed distance
            ])

        # 11. FIKIR (Index near Eye)
        if l_eye and r_eye and l_sh and r_sh and payload.imageSize:
            p_l_eye = p2s(l_eye)
            p_r_eye = p2s(r_eye)
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2
            d_eye = min((state.points[8] - p_l_eye).distance, (state.points[8] - p_r_eye).distance)

            add_single("FIKIR", [
                state.is_index_up,
                not state.is_thumb_up, not state.is_middle_up, not state.is_ring_up, not state.is_pinky_up,
                state.index_horizontal,
                state.points[8].dx > state.points[5].dx,  # Must point towards X=1 (Left)
                state.points[8].dy < sh_v,  # Must be above shoulder level
            ], [
                d_eye < 0.40,  # Relaxed distance
            ])

        # 21. ANDA & AWAK
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2
            strict_point = [
                state.is_index_up, not state.is_thumb_up, not state.is_middle_up, not state.is_ring_up, not state.is_pinky_up,
                state.index_horizontal,
                state.points[8].dx < state.points[5].dx,
                state.points[8].dy > sh_v,  # must below shoulder
            ]
            add_single("ANDA", strict_point, [])
            add_single("AWAK", strict_point, [])

        # 22. SANA (Index Up, Above Shoulder)
        above_shoulder = False
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2
            if state.points[0].dy < sh_v:
                above_shoulder = True

        add_single("SANA", [
            state.is_index_up, not state.is_thumb_up, not state.is_middle_up, not state.is_ring_up, not state.is_pinky_up,
            state.index_horizontal,
            state.points[8].dx < state.points[5].dx,
            above_shoulder,
        ], [
            above_shoulder,
        ])

        # MAAF (Fist near chest, thumb horizontal)
        if l_sh and r_sh and payload.imageSize:
            p_l_sh = p2s(l_sh)
            p_r_sh = p2s(r_sh)
            s_mid = Offset((p_l_sh.dx + p_r_sh.dx) / 2, (p_l_sh.dy + p_r_sh.dy) / 2)
            chest = Offset(s_mid.dx, s_mid.dy + 0.20)
            d_chest = (state.points[0] - chest).distance

            add_single("MAAF", [
                not state.is_thumb_up, not state.is_index_up, not state.is_middle_up, not state.is_ring_up, not state.is_pinky_up,
                state.index_horizontal, state.thumb_horizontal,
                d_chest < 0.45,
            ], [])



def check_two_hand_gestures(h_states: List[Any], payload: Any, p2s: Any, pose: Dict[str, Any], add_two: Any):
    l_sh = pose.get("leftShoulder")
    r_sh = pose.get("rightShoulder")
    l_mouth = pose.get("leftMouth")
    r_mouth = pose.get("rightMouth")
    nose = pose.get("nose")
    l_eye = pose.get("leftEye")
    r_eye = pose.get("rightEye")

    # Two Hand Signs
    if len(h_states) == 2:
        # 13. Apa Khabar (Two Thumbs Up near chest, Below Shoulder)
        if l_sh and r_sh and payload.imageSize:
            p_l_sh = p2s(l_sh)
            p_r_sh = p2s(r_sh)
            s_mid = Offset((p_l_sh.dx + p_r_sh.dx) / 2, (p_l_sh.dy + p_r_sh.dy) / 2)
            chest = Offset(s_mid.dx, s_mid.dy + 0.20)
            sh_v = (p_l_sh.dy + p_r_sh.dy) / 2

            strict_khabar = []
            score_khabar = []
            for s in h_states:
                # Strict Finger Status: Thumbs up only
                strict_khabar.append(s.is_thumb_up and not s.is_index_up and not s.is_middle_up and not s.is_ring_up and not s.is_pinky_up)
                # Strict Orientation: Thumb Vertical
                strict_khabar.append(s.thumb_vertical)

                score_khabar.append(s.points[4].dy < s.points[2].dy)
                score_khabar.append(s.index_horizontal)
                score_khabar.append(s.points[0].dy > sh_v - 0.05)
                score_khabar.append((s.points[0] - chest).distance < 0.45)

            add_two("Apa Khabar", strict_khabar, score_khabar)

        # 14. BOLEH (Two Fists at shoulders)
        if l_sh and r_sh and payload.imageSize:
            p_l_sh = p2s(l_sh)
            p_r_sh = p2s(r_sh)

            strict_boleh = []
            score_boleh = []
            for s in h_states:
                # Strict Finger Status: All closed
                strict_boleh.append(not s.is_thumb_up and not s.is_index_up and not s.is_middle_up and not s.is_ring_up and not s.is_pinky_up)
                # Strict Orientation: Vertical
                strict_boleh.append(s.is_vertical)
                score_boleh.append(s.move_dir == "UP")

            # Position: Each hand at one shoulder
            h0_l = (h_states[0].points[0] - p_l_sh).distance < 0.25
            h0_r = (h_states[0].points[0] - p_r_sh).distance < 0.25
            h1_l = (h_states[1].points[0] - p_l_sh).distance < 0.25
            h1_r = (h_states[1].points[0] - p_r_sh).distance < 0.25

            score_boleh.append((h0_l and h1_r) or (h0_r and h1_l))
            add_two("BOLEH", strict_boleh, score_boleh)

        # 15. TIDAK ADA (Two Open Palms, Below Shoulder)
        sh_v = 0.5
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2

        strict_ada = []
        score_ada = []
        for s in h_states:
            # Strict Finger Status: All open
            strict_ada.append(s.is_thumb_up and s.is_index_up and s.is_middle_up and s.is_ring_up and s.is_pinky_up)
            # Strict Orientation: Index vertical, Thumb horizontal
            strict_ada.append(s.index_vertical and s.thumb_horizontal)

            score_ada.append(s.points[8].dy < s.points[5].dy)
            score_ada.append(s.points[0].dy > sh_v)

        add_two("TIDAK ADA", strict_ada, score_ada)

        # 16. LESEN (Two Hands, Index+Thumb Up, Index Vertical, Thumb Horizontal, Near Chest)
        if l_sh and r_sh and payload.imageSize:
            p_l_sh = p2s(l_sh)
            p_r_sh = p2s(r_sh)
            s_mid = Offset((p_l_sh.dx + p_r_sh.dx) / 2, (p_l_sh.dy + p_r_sh.dy) / 2)
            chest = Offset(s_mid.dx, s_mid.dy + 0.20)

            strict_lesen = []
            score_lesen = []
            for s in h_states:
                strict_lesen.append(s.is_index_up and s.is_thumb_up and not s.is_middle_up and not s.is_ring_up and not s.is_pinky_up)
                strict_lesen.append(s.index_vertical and s.thumb_horizontal)
                score_lesen.append(s.points[8].dy < s.points[5].dy)  # Index tip pointing UP
                score_lesen.append((s.points[0] - chest).distance < 0.40)

            # Hands should be relatively close to each other, specifically thumbs touching
            thumb_dist = (h_states[0].points[4] - h_states[1].points[4]).distance
            strict_lesen.append(thumb_dist < 0.15)  # Strict "touching" distance

            add_two("LESEN", strict_lesen, score_lesen)

        # 17. BENANG (Two Hands, Pinky Only, Horizontal, Close Together, Below Shoulder)
        sh_v = 0.5
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2

        strict_benang = []
        score_benang = []
        for s in h_states:
            strict_benang.append(s.is_pinky_up and not s.is_thumb_up and not s.is_index_up and not s.is_middle_up and not s.is_ring_up)
            strict_benang.append(s.pinky_horizontal)
            score_benang.append(s.points[0].dy > sh_v)

        d_pinky = (h_states[0].points[20] - h_states[1].points[20]).distance
        score_benang.append(d_pinky < 0.35)

        add_two("BENANG", strict_benang, score_benang)

        # 18. NAMA (Two Hands, Index+Middle Up, Horizontal, Close Together, Below Shoulder)
        sh_v = 0.5
        if l_sh and r_sh and payload.imageSize:
            sh_v = (p2s(l_sh).dy + p2s(r_sh).dy) / 2

        strict_nama = []
        score_nama = []
        for s in h_states:
            strict_nama.append(s.is_index_up and s.is_middle_up and not s.is_ring_up and not s.is_pinky_up)
            strict_nama.append(s.index_horizontal)
            score_nama.append(s.points[0].dy > sh_v)

        center0 = Offset((h_states[0].points[8].dx + h_states[0].points[12].dx) / 2, (h_states[0].points[8].dy + h_states[0].points[12].dy) / 2)
        center1 = Offset((h_states[1].points[8].dx + h_states[1].points[12].dx) / 2, (h_states[1].points[8].dy + h_states[1].points[12].dy) / 2)
        strict_nama.append((center0 - center1).distance < 0.15)  # Strict "stacked" distance
        add_two("NAMA", strict_nama, score_nama)

        # 23. TOLONG (Help)
        s0 = h_states[0]
        s1 = h_states[1]

        # Identify top and bottom hand based on wrist Y
        top = s0 if s0.points[0].dy < s1.points[0].dy else s1
        bottom = s1 if s0.points[0].dy < s1.points[0].dy else s0

        # Top hand: BAGUS (thumb up)
        # Bottom hand: PALM (flat)
        top_up_count = (1 if top.is_index_up else 0) + (1 if top.is_middle_up else 0) + (1 if top.is_ring_up else 0) + (1 if top.is_pinky_up else 0)
        bottom_up_count = (1 if bottom.is_index_up else 0) + (1 if bottom.is_middle_up else 0) + (1 if bottom.is_ring_up else 0) + (1 if bottom.is_pinky_up else 0)

        add_two("TOLONG", [
            top.points[0].dy < bottom.points[0].dy - 0.02,  # Vertical separation
            top.is_thumb_up,
            bottom_up_count >= 2,  # Palm hand needs at least 2 fingers open
        ], [
            top_up_count <= 1,
            bottom.is_horizontal,
            bottom.thumb_horizontal,
            abs(top.points[0].dx - bottom.points[0].dx) < 0.45,  # Relaxed alignment
            top.thumb_vertical,
        ])

        # 23.5 BERHENTI (Two Hands Palm version)
        top_up_count_b = (1 if top.is_index_up else 0) + (1 if top.is_middle_up else 0) + (1 if top.is_ring_up else 0) + (1 if top.is_pinky_up else 0)
        bottom_up_count_b = (1 if bottom.is_index_up else 0) + (1 if bottom.is_middle_up else 0) + (1 if bottom.is_ring_up else 0) + (1 if bottom.is_pinky_up else 0)

        add_two("BERHENTI ", [
            top.points[0].dy < bottom.points[0].dy - 0.02,  # Vertical separation
            top_up_count_b >= 3,  # Top hand flat palm
            bottom_up_count_b >= 3,  # Bottom hand flat palm
        ], [
            top.is_horizontal,
            bottom.is_horizontal,
            bottom.index_horizontal,
            abs(top.points[0].dx - bottom.points[0].dx) < 0.45,  # Relaxed alignment
        ])

        # 24. BETUL (Two Hands, Index Up only, Horizontal, Near Chest, Below Shoulder)
        if l_sh and r_sh and payload.imageSize:
            p_l_sh = p2s(l_sh)
            p_r_sh = p2s(r_sh)
            s_mid = Offset((p_l_sh.dx + p_r_sh.dx) / 2, (p_l_sh.dy + p_r_sh.dy) / 2)
            chest = Offset(s_mid.dx, s_mid.dy + 0.20)
            sh_v = (p_l_sh.dy + p_r_sh.dy) / 2

            strict_betul = []
            score_betul = []
            for s in h_states:
                strict_betul.append(s.is_index_up and not s.is_thumb_up and not s.is_middle_up and not s.is_ring_up and not s.is_pinky_up)
                strict_betul.append(s.index_horizontal)
                score_betul.append(s.points[0].dy > sh_v)  # Wrist below shoulder
                score_betul.append((s.points[0] - chest).distance < 0.45)

            # Hands must be stacked (one above the other)
            dy_diff = abs(h_states[0].points[0].dy - h_states[1].points[0].dy)
            dx_diff = abs(h_states[0].points[0].dx - h_states[1].points[0].dx)
            strict_betul.append(dy_diff > 0.05)  # Vertical separation
            score_betul.append(dx_diff < 0.20)  # Horizontal alignment

            # Both index fingers pointing in the same direction
            h0_right = h_states[0].points[8].dx > h_states[0].points[5].dx
            h1_right = h_states[1].points[8].dx > h_states[1].points[5].dx
            strict_betul.append(h0_right == h1_right)

            add_two("BETUL", strict_betul, score_betul)




