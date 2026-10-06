-- Reference data: the three drying-quality classes.
-- NOTE: the descriptions are a first draft written by the developer; please review them
-- with your instructor / copra grader before final submission.
INSERT INTO kopragrade.quality_classes (class_name, description) VALUES
 ('Well-Dried',       'Copra is fully dried: firm, clean and light-colored with no visible moisture or mold.'),
 ('Moderately Dried', 'Copra is partly dried: acceptable but still slightly soft or uneven in color, may need more drying.'),
 ('Poorly Dried',     'Copra is under-dried or damaged: soft, dark or moldy in places, poor drying quality.')
ON CONFLICT (class_name) DO NOTHING;
