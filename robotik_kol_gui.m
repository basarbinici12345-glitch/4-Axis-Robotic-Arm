function robotik_kol_gui()
% ============================================================
%  ROBOTİK KOL KONTROL PANELİ
%  - IK görselleştirme (klavye ile X/Z kontrolü)
%  - Hip yayı (yarım daire üzerinde sürüklenebilir kontrol)
%  - Gripper toggle butonu (Kırmızı=Kapalı / Yeşil=Açık)
%  - STM32 G-code UART iletişimi
% ============================================================
    % --- KOL PARAMETRELERİ ---
    shoulder_length = 20;  % 18'den 20'ye güncellendi
    elbow_length    = 20;  % 18'den 20'ye güncellendi
    x = 20;                % 90 derece dik açı şovu bozulmasın diye 20 yapıldı
    z = 20;                % 90 derece dik açı şovu bozulmasın diye 20 yapıldı
    % --- HIP & GRİPPER DURUM ---
    hip_deg     = 90;      % başlangıç: orta (90°)
    grip_open   = false;   % false=kapalı(kırmızı), true=açık(yeşil)
    % --- UART ---
    port     = 'COM7';
    baudrate = 115200;
    s = serialport(port, baudrate);
    configureTerminator(s, "CR/LF");
    s.Timeout = 2;
    disp('UART bağlandı...');
    pause(0.5);
    % ============================================================
    %  ANA FIGURE — koyu endüstriyel tema
    % ============================================================
    fig = figure( ...
        'Name',            'ROBOTİK KOL KONTROL PANELİ', ...
        'NumberTitle',     'off', ...
        'Color',           [0.10 0.11 0.13], ...
        'Position',        [80 80 1200 680], ...
        'KeyPressFcn',     @klavye_cb, ...
        'CloseRequestFcn', @kapat_cb, ...
        'Resize',          'off');
    % ============================================================
    %  PANEL 1 — IK GÖRSELİ  (sol)
    % ============================================================
    ax_ik = axes('Parent', fig, ...
        'Position',  [0.04 0.10 0.42 0.82], ...
        'Color',     [0.12 0.13 0.16], ...
        'XColor',    [0.45 0.55 0.65], ...
        'YColor',    [0.45 0.55 0.65], ...
        'GridColor', [0.25 0.28 0.32], ...
        'GridAlpha', 0.6, ...
        'FontName',  'Consolas', ...
        'FontSize',  9);
    hold(ax_ik, 'on');
    grid(ax_ik, 'on');
    axis(ax_ik, 'equal');
    xlim(ax_ik, [-5 45]); % Kol uzadığı için limitleri biraz açtık
    ylim(ax_ik, [-5 45]);
    xlabel(ax_ik, 'X  (cm)', 'Color', [0.55 0.65 0.75]);
    ylabel(ax_ik, 'Z  (cm)', 'Color', [0.55 0.65 0.75]);
    title(ax_ik, 'IK  GÖRSELİ', ...
        'Color', [0.80 0.88 0.95], 'FontName', 'Consolas', 'FontSize', 11);
    % Erişim dairesi
    theta_reach = linspace(0, pi/2, 120);
    max_reach   = shoulder_length + elbow_length - 0.1;
    plot(ax_ik, max_reach*cos(theta_reach), max_reach*sin(theta_reach), ...
        '--', 'Color', [0.35 0.40 0.45], 'LineWidth', 1);
    % Kol çizgisi
    plot_arm = plot(ax_ik, [0,0,0], [0,0,0], '-o', ...
        'LineWidth',      4, ...
        'Color',          [0.25 0.70 0.95], ...
        'MarkerSize',     8, ...
        'MarkerFaceColor',[0.95 0.95 0.95], ...
        'MarkerEdgeColor',[0.25 0.70 0.95]);
    % Hedef noktası
    plot_aim = plot(ax_ik, x, z, '+', ...
        'MarkerSize', 14, 'LineWidth', 2.5, 'Color', [1.0 0.35 0.25]);
    % Bilgi etiketi (sol üst)
    lbl_info = text(ax_ik, -4, 42, '', ...
        'Color',    [0.75 0.85 0.95], ...
        'FontName', 'Consolas', ...
        'FontSize', 9);
    % ============================================================
    %  PANEL 2 — HIP YAYI  (sağ üst)
    % ============================================================
    ax_hip = axes('Parent', fig, ...
        'Position', [0.52 0.38 0.44 0.56], ...
        'Color',    [0.12 0.13 0.16], ...
        'XColor',   'none', ...
        'YColor',   'none');
    hold(ax_hip, 'on');
    axis(ax_hip, 'equal');
    xlim(ax_hip, [-1.35 1.35]);
    ylim(ax_hip, [-0.20 1.35]);
    title(ax_hip, 'HIP  KONTROLÜ  ( ← → )', ...
        'Color', [0.80 0.88 0.95], 'FontName', 'Consolas', 'FontSize', 11);
    % Arka plan yayı (gri)
    t_arc  = linspace(0, pi, 200);
    R_arc  = 1.0;
    plot(ax_hip, R_arc*cos(t_arc), R_arc*sin(t_arc), ...
        '-', 'Color', [0.28 0.32 0.38], 'LineWidth', 14);
    % Aktif yay parçası (mavi) — başlangıçta 90°
    arc_active = plot(ax_hip, nan, nan, ...
        '-', 'Color', [0.20 0.60 0.90], 'LineWidth', 14);
    % Derece işaretleri
    for deg = 0:30:180
        ang = deg * pi / 180;
        r1  = 0.88; r2 = 1.12;
        plot(ax_hip, [r1*cos(ang) r2*cos(ang)], [r1*sin(ang) r2*sin(ang)], ...
            '-', 'Color', [0.38 0.42 0.48], 'LineWidth', 1.5);
        text(ax_hip, 1.22*cos(ang), 1.22*sin(ang), sprintf('%d°',deg), ...
            'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
            'Color', [0.55 0.62 0.70], 'FontName','Consolas','FontSize',8);
    end
    % Ok (yay üzerindeki daire)
    hip_handle = plot(ax_hip, ...
        R_arc*cos(hip_deg*pi/180), R_arc*sin(hip_deg*pi/180), 'o', ...
        'MarkerSize',     18, ...
        'MarkerFaceColor',[0.20 0.65 0.95], ...
        'MarkerEdgeColor',[0.90 0.95 1.00], ...
        'LineWidth',      2.5);
    % Hip derece etiketi
    lbl_hip = text(ax_hip, 0, -0.10, sprintf('Hip: %.0f°', hip_deg), ...
        'HorizontalAlignment', 'center', ...
        'Color',    [0.85 0.92 1.00], ...
        'FontName', 'Consolas', ...
        'FontSize', 13, ...
        'FontWeight','bold');
    % Yay tıklama / sürükleme
    set(fig, 'WindowButtonDownFcn',   @arc_click_cb);
    set(fig, 'WindowButtonMotionFcn', @arc_drag_cb);
    set(fig, 'WindowButtonUpFcn',     @arc_release_cb);
    arc_dragging = false;
    % ============================================================
    %  PANEL 3 — GRİPPER BUTONU  (sağ alt)
    % ============================================================
    % Arka panel
    uipanel('Parent', fig, ...
        'Position',       [0.52 0.04 0.44 0.30], ...
        'BackgroundColor',[0.12 0.13 0.16], ...
        'BorderType',     'line', ...
        'HighlightColor', [0.22 0.26 0.30], ...
        'Title',          'GRİPPER KONTROLÜ', ...
        'ForegroundColor',[0.80 0.88 0.95], ...
        'FontName',       'Consolas', ...
        'FontSize',       11);
    % Durum lambası (küçük daire — uipanel içinde değil, figure üzerinde)
    ax_lamp = axes('Parent', fig, ...
        'Position', [0.57 0.10 0.08 0.16], ...
        'Color',    [0.12 0.13 0.16], ...
        'XColor',   'none', 'YColor', 'none');
    hold(ax_lamp,'on');
    axis(ax_lamp,'equal');
    xlim(ax_lamp,[-1.2 1.2]); ylim(ax_lamp,[-1.2 1.2]);
    theta_c  = linspace(0,2*pi,120);
    lamp_bg  = fill(ax_lamp, cos(theta_c), sin(theta_c), [0.60 0.12 0.10], ...
        'EdgeColor',[0.90 0.90 0.90],'LineWidth',1.5);
    lamp_txt = text(ax_lamp, 0, 0, 'KAPALI', ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'Color',[1 1 1],'FontName','Consolas','FontSize',9,'FontWeight','bold');
    % Ana toggle butonu
    btn_grip = uicontrol('Parent', fig, ...
        'Style',           'pushbutton', ...
        'String',          '▶  GRIPPER AÇ', ...
        'Units',           'normalized', ...
        'Position',        [0.68 0.10 0.24 0.16], ...
        'BackgroundColor', [0.18 0.42 0.18], ...
        'ForegroundColor', [0.70 1.00 0.70], ...
        'FontName',        'Consolas', ...
        'FontSize',        12, ...
        'FontWeight',      'bold', ...
        'Callback',        @gripper_cb);
    % ============================================================
    %  ALT BİLGİ BARI
    % ============================================================
    lbl_uart = uicontrol('Parent', fig, ...
        'Style',           'text', ...
        'Units',           'normalized', ...
        'Position',        [0.04 0.01 0.92 0.045], ...
        'BackgroundColor', [0.08 0.09 0.11], ...
        'ForegroundColor', [0.45 0.85 0.55], ...
        'FontName',        'Consolas', ...
        'FontSize',        9, ...
        'HorizontalAlignment','left', ...
        'String',          '  ● UART hazır — COM7 @ 115200');
    % ============================================================
    %  İLK ÇİZİM
    % ============================================================
    ik_calc();
    arc_guncelle();
    % ============================================================
    %  CALLBACK: KLAVYE
    % ============================================================
    function klavye_cb(~, event)
        adim = 0.4;
        switch event.Key
            case 'a'           % <--- Senin özel tuş ataman burada
                z = z + adim;
            case 'downarrow'
                z = z - adim;
            case 'rightarrow'
                % ismember ile güvenli Shift kontrolü
                if ismember('shift', event.Modifier)
                    hip_deg = min(180, hip_deg + 5);
                    arc_guncelle(); 
                    uart_hip_gonder();
                else
                    x = x + adim;
                end
            case 'leftarrow'
                % ismember ile güvenli Shift kontrolü
                if ismember('shift', event.Modifier)
                    hip_deg = max(0, hip_deg - 5);
                    arc_guncelle(); 
                    uart_hip_gonder();
                else
                    x = x - adim;
                end
            otherwise
                return;
        end
        ik_calc();
    end
    % ============================================================
    %  IK HESAP + UART GÖNDER
    % ============================================================
    function ik_calc()
        dist      = sqrt(x^2 + z^2);
        max_reach = shoulder_length + elbow_length - 0.01;
        if dist > max_reach, dist = max_reach; end
        if dist < 0.1,       dist = 0.1;       end
        alpha1     = atan2(z, x);
        cos_alpha2 = (shoulder_length^2 + dist^2 - elbow_length^2) ...
                     / (2 * shoulder_length * dist);
        cos_alpha2 = max(-1, min(1, cos_alpha2));
        alpha2     = acos(cos_alpha2);
        cos_beta   = (shoulder_length^2 + elbow_length^2 - dist^2) ...
                     / (2 * shoulder_length * elbow_length);
        cos_beta   = max(-1, min(1, cos_beta));
        beta       = acos(cos_beta);
        shoulder_total = alpha1 + alpha2;
        elbow_x = shoulder_length * cos(shoulder_total);
        elbow_z = shoulder_length * sin(shoulder_total);
        tip_ang = shoulder_total - (pi - beta);
        tip_x   = elbow_x + elbow_length * cos(tip_ang);
        tip_z   = elbow_z + elbow_length * sin(tip_ang);
        % Kol güncelle
        set(plot_arm, 'XData', [0, elbow_x, tip_x], ...
                      'YData', [0, elbow_z, tip_z]);
        set(plot_aim, 'XData', tip_x, 'YData', tip_z); 
        set(lbl_info, 'String', sprintf( ...
            'Omuz: %.1f°\nDirsek: %.1f°\nX: %.1f  Z: %.1f', ...
            rad2deg(shoulder_total), rad2deg(beta), x, z));
        drawnow;
        % G-code gönder (X=R yatay mesafe, Y=Z dikey)
        gcode = sprintf('G1 X%.2f Y%.2f Z%.2f', x, z, hip_deg);
        uart_gonder(gcode);
    end
    % ============================================================
    %  HİP UART GÖNDER
    % ============================================================
    function uart_hip_gonder()
        gcode = sprintf('G1 Z%.2f', hip_deg);
        uart_gonder(gcode);
    end
    % ============================================================
    %  GENEL UART GÖNDER
    % ============================================================
    function uart_gonder(gcode)
        try
            writeline(s, gcode);
            set(lbl_uart, 'String', sprintf('  ● TX: %s', gcode), ...
                'ForegroundColor', [0.45 0.85 0.55]);
            cevap = readline(s);
            set(lbl_uart, 'String', ...
                sprintf('  ● TX: %s    RX: %s', gcode, strtrim(cevap)), ...
                'ForegroundColor', [0.45 0.85 0.55]);
        catch
            set(lbl_uart, 'String', ...
                sprintf('  ⚠ Timeout — %s gönderilemedi', gcode), ...
                'ForegroundColor', [1.00 0.55 0.25]);
        end
    end
    % ============================================================
    %  HİP YAYI GÜNCELLE
    % ============================================================
    function arc_guncelle()
        ang = hip_deg * pi / 180;
        % Aktif yay (0° → hip_deg)
        t_a = linspace(0, ang, 120);
        set(arc_active, 'XData', R_arc*cos(t_a), 'YData', R_arc*sin(t_a));
        % Daire konumu
        set(hip_handle, 'XData', R_arc*cos(ang), 'YData', R_arc*sin(ang));
        set(lbl_hip, 'String', sprintf('Hip:  %.0f°', hip_deg));
        drawnow;
    end
    % ============================================================
    %  YAY TIKLAMA / SÜRÜKLEME
    % ============================================================
    function arc_click_cb(~,~)
        pt = get(ax_hip, 'CurrentPoint');
        cx = pt(1,1); cy = pt(1,2);
        r  = sqrt(cx^2 + cy^2);
        % Yaydaki tıklama mı? (0.6–1.3 arası, üst yarım)
        if r > 0.6 && r < 1.3 && cy >= -0.1
            arc_dragging = true;
            arc_set_from_point(cx, cy);
        end
    end
    function arc_drag_cb(~,~)
        if ~arc_dragging, return; end
        pt = get(ax_hip, 'CurrentPoint');
        arc_set_from_point(pt(1,1), pt(1,2));
    end
    function arc_release_cb(~,~)
        if arc_dragging
            arc_dragging = false;
            uart_hip_gonder();
        end
    end
    function arc_set_from_point(cx, cy)
        ang     = atan2(cy, cx);
        ang     = max(0, min(pi, ang));
        hip_deg = ang * 180 / pi;
        arc_guncelle();
    end
    % ============================================================
    %  GRİPPER TOGGLE
    % ============================================================
    function gripper_cb(~,~)
        grip_open = ~grip_open;
        if grip_open
            % AÇIK — yeşil
            set(btn_grip, ...
                'String',          '■  GRIPPER KAPAT', ...
                'BackgroundColor', [0.45 0.18 0.15], ...
                'ForegroundColor', [1.00 0.70 0.65]);
            set(lamp_bg,  'FaceColor', [0.15 0.62 0.25]);
            set(lamp_txt, 'String', 'AÇIK');
            uart_gonder('M10');
        else
            % KAPALI — kırmızı
            set(btn_grip, ...
                'String',          '▶  GRIPPER AÇ', ...
                'BackgroundColor', [0.18 0.42 0.18], ...
                'ForegroundColor', [0.70 1.00 0.70]);
            set(lamp_bg,  'FaceColor', [0.60 0.12 0.10]);
            set(lamp_txt, 'String', 'KAPALI');
            uart_gonder('M11');
        end
    end
    % ============================================================
    %  KAPAT
    % ============================================================
    function kapat_cb(~,~)
        try, clear s; catch, end
        delete(fig);
        disp('UART kapatıldı.');
    end
end